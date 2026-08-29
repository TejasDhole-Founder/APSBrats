package com.apsconnect.api.common.response;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
@JsonInclude(JsonInclude.Include.NON_NULL)
public class ApiResponse<T> {
    private boolean success;
    private String message;
    private T data;
    private String error;
    private String code;
    private String requestId;

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
