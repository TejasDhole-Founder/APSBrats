package com.apsconnect.api.community;

import java.util.List;

/** The Communities tab: what I've joined, my schools' communities I could join, and my pending join requests. */
public record MyCommunitiesDto(List<CommunityDto> joined, List<CommunityDto> suggested, List<CommunityDto> requested) {
}
