package com.apsconnect.api.community;

import com.apsconnect.api.user.PersonDto;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

/**
 * A post as the app shows it. canDelete: I wrote it, or I moderate where it was posted.
 * canPin: I own the community, or I'm staff.
 */
public record PostDto(
        UUID id,
        UUID communityId,
        String communityName,
        PersonDto author,
        String body,
        List<String> imageUrls,
        int likeCount,
        int commentCount,
        boolean likedByMe,
        boolean canDelete,
        boolean pinned,
        boolean canPin,
        /** The event it was shared from, or null. */
        UUID eventId,
        String eventTitle,
        /** A school memory from this year and category, or both null. */
        Short memoryYear,
        MemoryCategory memoryCategory,
        LocalDateTime createdAt
) {
}
