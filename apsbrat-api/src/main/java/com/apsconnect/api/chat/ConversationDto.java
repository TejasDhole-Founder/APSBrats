package com.apsconnect.api.chat;

import com.apsconnect.api.user.PersonDto;

import java.time.LocalDateTime;
import java.util.UUID;

public record ConversationDto(
        UUID id,
        PersonDto person,
        String preview,
        LocalDateTime time,
        boolean unread,
        long unreadCount
) {
}
