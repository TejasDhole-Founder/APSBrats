package com.apsconnect.api.user.social;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record UpsertUserSocialLinkRequest(
        @NotBlank(message = "handle is required")
        @Size(max = 200, message = "handle must be at most 200 characters")
        String handle,

        @Size(max = 50, message = "label must be at most 50 characters")
        String label,

        Boolean isVisible
) {
}
