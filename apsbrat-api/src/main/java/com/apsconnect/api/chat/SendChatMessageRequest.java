package com.apsconnect.api.chat;

import jakarta.validation.constraints.Size;

/** Text, a photo, or both. At least one is required (checked in ChatService). */
public record SendChatMessageRequest(
        @Size(max = 4000, message = "body too long")
        String body,

        @Size(max = 300, message = "Invalid photo")
        String imageUrl
) {
}
