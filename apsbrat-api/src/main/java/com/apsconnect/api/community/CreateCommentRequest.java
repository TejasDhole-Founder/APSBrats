package com.apsconnect.api.community;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateCommentRequest(
        @NotBlank(message = "Write something first")
        @Size(max = 1000, message = "Comments can be at most 1,000 characters")
        String body
) {
}
