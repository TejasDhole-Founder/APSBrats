package com.apsconnect.api.user;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ChangePasswordRequest(
        String currentPassword,

        @NotBlank(message = "newPassword is required")
        @Size(min = 8, max = 72, message = "newPassword must be between 8 and 72 characters")
        String newPassword,

        @NotBlank(message = "confirmPassword is required")
        String confirmPassword
) {
}
