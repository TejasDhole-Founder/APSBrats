package com.apsconnect.api.profile;

import com.apsconnect.api.user.UserStatus;
import com.apsconnect.api.user.social.UserSocialLinkDto;

import java.util.List;
import java.util.UUID;

public record ProfileDto(
        UUID id,
        String username,
        String fullName,
        String bio,
        String city,
        String profession,
        String profilePicUrl,
        boolean isVerified,
        UserStatus currentStatus,
        List<SchoolHistoryDto> schools,
        List<UserSocialLinkDto> socials,
        long batchmatesCount,
        long schoolsCount,
        long connectedCount
) {
}
