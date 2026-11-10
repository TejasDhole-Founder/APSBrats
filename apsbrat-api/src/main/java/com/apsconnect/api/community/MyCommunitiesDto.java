package com.apsconnect.api.community;

import java.util.List;

/** The Communities tab: what I've joined, and my schools' communities I could join. */
public record MyCommunitiesDto(List<CommunityDto> joined, List<CommunityDto> suggested) {
}