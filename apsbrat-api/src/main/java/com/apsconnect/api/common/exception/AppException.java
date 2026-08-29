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
