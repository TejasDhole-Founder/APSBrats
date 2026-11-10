package com.apsconnect.api.community;

import com.apsconnect.api.user.PersonDto;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * A community chat message. The same copy goes to every member, so there are no
 * per-viewer flags: the app compares sender.id with its own id, and the chat
 * summary says whether the viewer can moderate.
 * removed = true is a live notice that the message was deleted or hidden.
 */
public record CommunityMessageDto(
        UUID id,
        UUID communityId,
        PersonDto sender,
        String body,
        String imageUrl,
        boolean removed,
        LocalDateTime createdAt
) {
}
