package com.apsconnect.api.community;

import jakarta.validation.constraints.Size;

import java.util.List;
import java.util.UUID;

/** Text, photos, or both. At least one is required (checked in PostService). */
public record CreatePostRequest(
        @Size(max = 2000, message = "Posts can be at most 2,000 characters")
        String body,

        @Size(max = PostService.MAX_PHOTOS, message = "A post can have at most 10 photos")
        List<String> imageUrls,

        /** Optional: photos shared from this event (same community, already started). */
        UUID eventId,

        /** Optional: mark as a school memory. Year and category go together, photos required. */
        Short memoryYear,
        MemoryCategory memoryCategory
) {
}
