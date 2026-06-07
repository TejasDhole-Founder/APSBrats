package com.apsconnect.api.auth;

import jakarta.validation.constraints.NotBlank;

public record VerifyOtpRequest(
        @NotBlank(message = "phone is required")
        String phone,

        @NotBlank(message = "code is required")
        String code
) {
}
