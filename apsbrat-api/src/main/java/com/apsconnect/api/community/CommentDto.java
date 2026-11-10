package com.apsconnect.api.community;

import com.apsconnect.api.user.PersonDto;

import java.time.LocalDateTime;
import java.util.UUID;

public record CommentDto(
        UUID id,
        UUID postId,
        PersonDto author,
        String body,
        boolean canDelete,
        LocalDateTime createdAt
) {
}
