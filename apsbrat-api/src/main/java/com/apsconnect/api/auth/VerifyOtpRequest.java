package com.apsconnect.api.auth;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public record VerifyOtpRequest(
        @NotBlank(message = "email is required")
        @Email(message = "email is not valid")
        String email,

        @NotBlank(message = "code is required")
        String code
) {
}
