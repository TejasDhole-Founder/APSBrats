package com.apsconnect.api.feed;

import java.util.List;

public record BatchmateBannerDto(
        int count,
        List<String> firstNames,
        String message
) {
}
