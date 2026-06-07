package com.apsconnect.api.chat;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record SendMessageRequest(
        @NotBlank(message = "body is required")
        @Size(max = 4000, message = "body too long")
        String body
) {
}
