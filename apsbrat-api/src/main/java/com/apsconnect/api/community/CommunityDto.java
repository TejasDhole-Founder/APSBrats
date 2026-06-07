package com.apsconnect.api.community;

import com.apsconnect.api.user.PersonDto;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

public record CommunityDto(
        UUID id,
        String name,
        String badge,
        CommunityType type,
        int members,
        int online,
        String lastSender,
        String lastMessage,
        LocalDateTime time,
        List<PersonDto> avatars,
        long unreadCount,
        String autoJoinLabel,
        boolean isYourSection,
        boolean isYourSchool
) {
}
