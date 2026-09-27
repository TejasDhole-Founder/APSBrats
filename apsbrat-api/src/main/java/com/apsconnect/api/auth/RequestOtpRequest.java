package com.apsconnect.api.auth;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public record RequestOtpRequest(
        @NotBlank(message = "email is required")
        @Email(message = "email is not valid")
        String email
) {
}
