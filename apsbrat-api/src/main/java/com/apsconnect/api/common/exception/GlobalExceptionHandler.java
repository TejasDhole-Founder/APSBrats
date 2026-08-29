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

    private static String rid() {
        return MDC.get(RequestIdFilter.MDC_KEY);
    }

    private ResponseEntity<ApiResponse<Void>> build(HttpStatus status, String msg, ErrorCode code) {
        return ResponseEntity.status(status).body(ApiResponse.error(msg, code.name(), rid()));
    }

    @ExceptionHandler(AppException.class)
    public ResponseEntity<ApiResponse<Void>> handleApp(AppException ex) {
        if (ex.getStatus().is5xxServerError()) {
            log.error("AppException: {}", ex.getMessage(), ex);
        } else {
            log.warn("AppException [{}]: {}", ex.getStatus().value(), ex.getMessage());
        }
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

    @ExceptionHandler({
            HttpMessageNotReadableException.class,
            MethodArgumentTypeMismatchException.class,
            MissingServletRequestParameterException.class
    })
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
        log.error("Data conflict", ex);
        return build(HttpStatus.CONFLICT, "This action conflicts with existing data", ErrorCode.CONFLICT);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponse<Void>> handleUnexpected(Exception ex) {
        log.error("Unhandled exception", ex);
        return build(HttpStatus.INTERNAL_SERVER_ERROR,
                "Something went wrong. Please try again. (ref: " + rid() + ")", ErrorCode.INTERNAL_ERROR);
    }
}
