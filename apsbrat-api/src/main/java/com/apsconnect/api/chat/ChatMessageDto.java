package com.apsconnect.api.chat;

import java.time.LocalDateTime;
import java.util.UUID;

public record ChatMessageDto(
        UUID id,
        UUID senderId,
        String body,
        boolean mine,
        LocalDateTime createdAt
) {
}
