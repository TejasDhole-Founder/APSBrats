package com.apsconnect.api.user;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

public record PersonDto(
        UUID id,
        String username,
        String initials,
        String name,
        String school,
        String detail,
        String city,
        String job,
        UserStatus currentStatus,
        String profilePicUrl,
        /** Active in the last few minutes (false when hidden). */
        boolean online,
        /** Last time they used the app; null when they or the viewer hide activity. */
        LocalDateTime lastActiveAt,
        List<String> tags,
        /** People connected to both the viewer and this person (0 when unknown). */
        int mutualCount,
        /** Viewer's relation to this person: NONE · PENDING_OUT · PENDING_IN · CONNECTED. */
        String relation
) {
}
