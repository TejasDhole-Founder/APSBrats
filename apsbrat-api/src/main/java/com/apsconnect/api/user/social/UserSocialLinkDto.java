package com.apsconnect.api.user.social;

import java.time.LocalDateTime;
import java.util.UUID;

public record UserSocialLinkDto(
        UUID id,
        UUID userId,
        SocialPlatform platform,
        String handle,
        String label,
        Boolean isVisible,
        LocalDateTime createdAt
) {
    public static UserSocialLinkDto from(UserSocialLink socialLink) {
        return new UserSocialLinkDto(
                socialLink.getId(),
                socialLink.getUser().getId(),
                socialLink.getPlatform(),
                socialLink.getHandle(),
                socialLink.getLabel(),
                socialLink.getIsVisible(),
                socialLink.getCreatedAt()
        );
    }
}
