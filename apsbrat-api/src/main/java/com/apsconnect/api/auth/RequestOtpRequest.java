package com.apsconnect.api.auth;

import jakarta.validation.constraints.NotBlank;

public record RequestOtpRequest(
        @NotBlank(message = "phone is required")
        String phone
) {
}
