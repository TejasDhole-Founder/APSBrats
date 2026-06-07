package com.apsconnect.api.feed;

import com.apsconnect.api.user.PersonDto;

import java.time.LocalDateTime;
import java.util.UUID;

public record FeedEventDto(
        UUID id,
        PersonDto person,
        FeedEventType type,
        String typeLabel,
        String title,
        String body,
        String meta,
        LocalDateTime createdAt
) {
}
