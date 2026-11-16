package com.apsconnect.api.profile;

import com.apsconnect.api.user.UserStatus;
import com.apsconnect.api.user.social.UserSocialLinkDto;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

public record ProfileDto(
        UUID id,
        String username,
        String fullName,
        String bio,
        String city,
        String profession,
        String phone,
        String profilePicUrl,
        boolean isVerified,
        UserStatus currentStatus,
        List<SchoolHistoryDto> schools,
        List<UserSocialLinkDto> socials,
        long schoolsCount,
        long connectedCount,
        /** Connections the viewer shares with this person (0 on own profile). */
        int mutualCount,
        /** True when the owner hides phone and socials from other users. */
        boolean isPrivate,
        /** Last time they used the app; null when they or the viewer hide activity. */
        LocalDateTime lastActiveAt,
        /** The account was deleted: only the name remains, everything else is blank. */
        boolean deleted
) {
}
