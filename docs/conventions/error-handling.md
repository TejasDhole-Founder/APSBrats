# Convention: Error Handling & API Errors (backend)

**Status: MANDATORY for all backend work (agents + humans).**
This replaces the current `GlobalExceptionHandler`, which catches `Exception`,
returns a generic 500, and **logs nothing** (`Exception ignored`) — meaning prod
failures are invisible and real 4xx cases get masked as 500.

---

## 1. Principles (the rules)
1. **Never swallow.** No empty `catch`, no `Exception ignored`. The catch-all MUST log the full stack at `ERROR`.
2. **Right status, not 500.** Map each exception to its correct HTTP status. A 4xx (bad input, not found, conflict, auth) must never surface as 500.
3. **Never leak internals.** Clients never receive stack traces, SQL, class names, or framework messages. 5xx returns a generic message + a `requestId` to quote to support.
4. **Machine-readable.** Every error carries a stable `code` (enum) so the app can branch on it, plus a `requestId` for correlation.
5. **Correlate.** Every request gets an `X-Request-Id` (propagated via MDC) that appears in logs and the error body.
6. **Log levels by class:** 4xx = `WARN` (no stack), 5xx = `ERROR` (with stack). Never log PII (phone, email, OTP, tokens, message bodies).
7. **Throw, don't improvise.** Services throw `AppException(message, status, code)` for expected errors. Never throw raw `RuntimeException` for control flow; never return error envelopes by hand from controllers.

## 2. Error response contract
```json
{
  "success": false,
  "message": null,
  "data": null,
  "error": "Human-readable, safe-to-show reason",
  "code": "NOT_FOUND",
  "requestId": "5b9c1f7e-..."
}
```
- `error` is safe to show the user. For 5xx it is generic ("Something went wrong, please try again").
- `code` is one of the `ErrorCode` enum values.
- `requestId` matches the `X-Request-Id` response header and the server logs.

## 3. Exception → status → code map
| Exception | HTTP | code | Log level |
|---|---|---|---|
| `AppException` (status carried) | its status | its code | 4xx warn / 5xx error |
| `MethodArgumentNotValidException` | 400 | `VALIDATION_ERROR` | warn |
| `ConstraintViolationException` | 400 | `VALIDATION_ERROR` | warn |
| `HttpMessageNotReadableException` (bad JSON) | 400 | `BAD_REQUEST` | warn |
| `MethodArgumentTypeMismatchException` (bad UUID etc.) | 400 | `BAD_REQUEST` | warn |
| `MissingServletRequestParameterException` | 400 | `BAD_REQUEST` | warn |
| `HttpRequestMethodNotSupportedException` | 405 | `METHOD_NOT_ALLOWED` | warn |
| `HttpMediaTypeNotSupportedException` | 415 | `UNSUPPORTED_MEDIA_TYPE` | warn |
| `MaxUploadSizeExceededException` | 413 | `PAYLOAD_TOO_LARGE` | warn |
| `AccessDeniedException` | 403 | `FORBIDDEN` | warn |
| `DataIntegrityViolationException` | 409 | `CONFLICT` | error (no SQL leak) |
| `OptimisticLockingFailureException` | 409 | `CONFLICT` | warn |
| anything else (`Exception`) | 500 | `INTERNAL_ERROR` | **error + stack** |

> Spring Security 401/403 thrown inside the filter chain are handled by an
> `AuthenticationEntryPoint` / `AccessDeniedHandler` in `SecurityConfig`, not by
> `@RestControllerAdvice`. Wire those to return the same envelope.

---

## 4. Reference implementation

### 4a. `ErrorCode`
```java
package com.apsconnect.api.common.exception;

public enum ErrorCode {
    VALIDATION_ERROR, BAD_REQUEST, UNAUTHORIZED, FORBIDDEN, NOT_FOUND,
    CONFLICT, RATE_LIMITED, PAYLOAD_TOO_LARGE, UNSUPPORTED_MEDIA_TYPE,
    METHOD_NOT_ALLOWED, INTERNAL_ERROR
}
```

### 4b. `AppException` (adds a code; keeps the old 2-arg constructor working)
```java
package com.apsconnect.api.common.exception;

import lombok.Getter;
import org.springframework.http.HttpStatus;

@Getter
public class AppException extends RuntimeException {
    private final HttpStatus status;
    private final ErrorCode code;

    public AppException(String message, HttpStatus status) {
        this(message, status, deriveCode(status));
    }

    public AppException(String message, HttpStatus status, ErrorCode code) {
        super(message);
        this.status = status;
        this.code = code;
    }

    private static ErrorCode deriveCode(HttpStatus s) {
        return switch (s) {
            case NOT_FOUND -> ErrorCode.NOT_FOUND;
            case CONFLICT -> ErrorCode.CONFLICT;
            case UNAUTHORIZED -> ErrorCode.UNAUTHORIZED;
            case FORBIDDEN -> ErrorCode.FORBIDDEN;
            case TOO_MANY_REQUESTS -> ErrorCode.RATE_LIMITED;
            default -> s.is5xxServerError() ? ErrorCode.INTERNAL_ERROR : ErrorCode.BAD_REQUEST;
        };
    }
}
```
Existing call sites (`new AppException("...", HttpStatus.NOT_FOUND)`) keep working.

### 4c. `ApiResponse` (add `code` + `requestId`; omit nulls)
```java
package com.apsconnect.api.common.response;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
@JsonInclude(JsonInclude.Include.NON_NULL)   // success responses don't carry null error/code/requestId
public class ApiResponse<T> {
    private boolean success;
    private String message;
    private T data;
    private String error;
    private String code;        // machine-readable, errors only
    private String requestId;   // correlation id, errors only

    public static <T> ApiResponse<T> success(T data) {
        return ApiResponse.<T>builder().success(true).data(data).build();
    }
    public static <T> ApiResponse<T> success(T data, String message) {
        return ApiResponse.<T>builder().success(true).data(data).message(message).build();
    }
    public static <T> ApiResponse<T> error(String error) {
        return ApiResponse.<T>builder().success(false).error(error).build();
    }
    public static <T> ApiResponse<T> error(String error, String code, String requestId) {
        return ApiResponse.<T>builder().success(false).error(error).code(code).requestId(requestId).build();
    }
}
```

### 4d. `RequestIdFilter` (correlation id in MDC + response header)
```java
package com.apsconnect.api.common.web;

import jakarta.servlet.FilterChain;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.MDC;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.util.UUID;

@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class RequestIdFilter extends OncePerRequestFilter {
    public static final String HEADER = "X-Request-Id";
    public static final String MDC_KEY = "requestId";

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws java.io.IOException, jakarta.servlet.ServletException {
        String id = req.getHeader(HEADER);
        if (id == null || id.isBlank()) id = UUID.randomUUID().toString();
        MDC.put(MDC_KEY, id);
        res.setHeader(HEADER, id);
        try {
            chain.doFilter(req, res);
        } finally {
            MDC.remove(MDC_KEY);
        }
    }
}
```

### 4e. `GlobalExceptionHandler` (mapped + logged + safe)
```java
package com.apsconnect.api.common.exception;

import com.apsconnect.api.common.response.ApiResponse;
import com.apsconnect.api.common.web.RequestIdFilter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

import java.util.stream.Collectors;

@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    private static String rid() { return MDC.get(RequestIdFilter.MDC_KEY); }

    private ResponseEntity<ApiResponse<Void>> build(HttpStatus status, String msg, ErrorCode code) {
        return ResponseEntity.status(status).body(ApiResponse.error(msg, code.name(), rid()));
    }

    @ExceptionHandler(AppException.class)
    public ResponseEntity<ApiResponse<Void>> handleApp(AppException ex) {
        if (ex.getStatus().is5xxServerError()) log.error("AppException: {}", ex.getMessage(), ex);
        else log.warn("AppException [{}]: {}", ex.getStatus().value(), ex.getMessage());
        return build(ex.getStatus(), ex.getMessage(), ex.getCode());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiResponse<Void>> handleValidation(MethodArgumentNotValidException ex) {
        String msg = ex.getBindingResult().getFieldErrors().stream()
                .map(e -> e.getField() + ": " + e.getDefaultMessage())
                .collect(Collectors.joining(", "));
        log.warn("Validation failed: {}", msg);
        return build(HttpStatus.BAD_REQUEST, msg, ErrorCode.VALIDATION_ERROR);
    }

    @ExceptionHandler({ HttpMessageNotReadableException.class, MethodArgumentTypeMismatchException.class,
            MissingServletRequestParameterException.class })
    public ResponseEntity<ApiResponse<Void>> handleBadRequest(Exception ex) {
        log.warn("Bad request: {}", ex.getMessage());
        return build(HttpStatus.BAD_REQUEST, "Malformed or missing request data", ErrorCode.BAD_REQUEST);
    }

    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    public ResponseEntity<ApiResponse<Void>> handleMethod(HttpRequestMethodNotSupportedException ex) {
        log.warn("Method not allowed: {}", ex.getMessage());
        return build(HttpStatus.METHOD_NOT_ALLOWED, "Method not allowed", ErrorCode.METHOD_NOT_ALLOWED);
    }

    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ApiResponse<Void>> handleDenied(AccessDeniedException ex) {
        log.warn("Access denied: {}", ex.getMessage());
        return build(HttpStatus.FORBIDDEN, "You do not have access to this resource", ErrorCode.FORBIDDEN);
    }

    @ExceptionHandler({ DataIntegrityViolationException.class, OptimisticLockingFailureException.class })
    public ResponseEntity<ApiResponse<Void>> handleConflict(Exception ex) {
        log.error("Data conflict", ex);   // log internally, do NOT leak SQL to client
        return build(HttpStatus.CONFLICT, "This action conflicts with existing data", ErrorCode.CONFLICT);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponse<Void>> handleUnexpected(Exception ex) {
        log.error("Unhandled exception", ex);   // FULL stack, always
        return build(HttpStatus.INTERNAL_SERVER_ERROR,
                "Something went wrong. Please try again. (ref: " + rid() + ")", ErrorCode.INTERNAL_ERROR);
    }
}
```

### 4f. Logback pattern — `src/main/resources/logback-spring.xml`
```xml
<configuration>
  <appender name="STDOUT" class="ch.qos.logback.core.ConsoleAppender">
    <encoder>
      <pattern>%d{yyyy-MM-dd HH:mm:ss.SSS} %-5level [%X{requestId:-no-rid}] %logger{36} - %msg%n</pattern>
    </encoder>
  </appender>
  <root level="INFO"><appender-ref ref="STDOUT"/></root>
</configuration>
```
(For prod, switch to a JSON encoder so logs are queryable; keep `%X{requestId}`.)

---

## 5. How services throw
```java
// expected, mapped error:
throw new AppException("Community not found", HttpStatus.NOT_FOUND);              // code auto = NOT_FOUND
throw new AppException("OTP expired", HttpStatus.BAD_REQUEST, ErrorCode.RATE_LIMITED);

// NEVER:
throw new RuntimeException("not found");     // becomes a 500
catch (Exception e) { /* ignored */ }        // silent failure
return ApiResponse.error("oops");            // bypasses the advice
```
If you must catch to add context, **log and rethrow** — never absorb.

## 6. Don't-leak rules
- No stack traces, SQL, class names, or `ex.getMessage()` from framework/DB exceptions in the `error` field.
- `AppException.getMessage()` is developer-authored and safe to return.
- No PII in logs: never log phone, email, OTP code, JWT, or message text.

## 7. Testing (required when touching this area)
A `@WebMvcTest` (or full `@SpringBootTest`) must cover:
- validation error → 400 + `code: VALIDATION_ERROR`
- not found → 404 + `code: NOT_FOUND`
- conflict → 409 + `code: CONFLICT`
- a forced unexpected exception → 500 + generic message + `requestId` present, and assert it was logged.

## 8. Rollout in this project (steps)
1. Add `ErrorCode`, `RequestIdFilter`, `logback-spring.xml`.
2. Update `AppException` (add code) and `ApiResponse` (add code + requestId + `@JsonInclude`).
3. Replace `GlobalExceptionHandler` with §4e.
4. Add `AuthenticationEntryPoint` + `AccessDeniedHandler` in `SecurityConfig` returning the same envelope for 401/403.
5. Update the Flutter `ApiResponse` model to read `code`/`requestId`; surface friendly messages by `code`; show `requestId` on unexpected errors for support.
6. Add the tests in §7.
