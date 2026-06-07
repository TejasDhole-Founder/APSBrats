package com.apsconnect.api.community;

import java.util.UUID;

public record DiscoverCommunityDto(
        UUID id,
        String name,
        String memberCount,
        String subtitle
) {
}
