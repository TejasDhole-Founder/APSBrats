package com.apsconnect.api.community;

import com.apsconnect.api.user.PersonDto;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * An event as the app shows it. myRsvp: GOING, INTERESTED or null.
 * canManage: I may edit or cancel it (community owner or staff).
 */
public record EventDto(
        UUID id,
        UUID communityId,
        String communityName,
        String title,
        String description,
        String venue,
        LocalDateTime startsAt,
        LocalDateTime endsAt,
        String coverUrl,
        boolean cancelled,
        PersonDto organizer,
        long goingCount,
        long interestedCount,
        /** Posts (photos) shared from it. */
        long photoCount,
        EventRsvp.Status myRsvp,
        boolean canManage
) {
}
