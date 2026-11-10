package com.apsconnect.api.community;

import java.util.UUID;

/**
 * A community as the app sees it. myRole is null when I'm not a member;
 * requested is true when I've asked to join a PRIVATE one and wait for approval.
 */
public record CommunityDto(
        UUID id,
        CommunityType type,
        String name,
        String description,
        CommunityVisibility visibility,
        int memberCount,
        MemberRole myRole,
        boolean requested
) {
    public static CommunityDto of(Community c, MemberRole myRole, boolean requested) {
        return new CommunityDto(c.getId(), c.getType(), c.getName(), c.getDescription(),
                c.getVisibility(), c.getMemberCount(), myRole, requested);
    }
}