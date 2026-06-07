package com.apsconnect.api.community;

import com.apsconnect.api.user.PersonDto;

import java.time.LocalDateTime;
import java.util.UUID;

public record CommunityMessageDto(
        UUID id,
        UUID senderId,
        PersonDto sender,
        String body,
        boolean mine,
        LocalDateTime createdAt
) {
}
