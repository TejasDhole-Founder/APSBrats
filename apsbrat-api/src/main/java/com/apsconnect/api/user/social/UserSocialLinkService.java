package com.apsconnect.api.user.social;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.user.User;
import com.apsconnect.api.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class UserSocialLinkService {
    private final UserRepository userRepository;
    private final UserSocialLinkRepository userSocialLinkRepository;
    private final com.apsconnect.api.safety.UserBlockRepository blockRepository;
    private final com.apsconnect.api.user.settings.UserSettingsService settingsService;

    /**
     * My own links, all of them. Someone else's: only the ones they show, nothing
     * if their profile is Private, and a 404 if either of us blocked the other
     * (the same rules as the profile page).
     */
    public List<UserSocialLinkDto> getLinks(UUID viewerId, UUID userId) {
        ensureUserExists(userId);
        boolean self = viewerId.equals(userId);
        if (!self && blockRepository.existsBetween(viewerId, userId)) {
            throw new AppException("User not found", HttpStatus.NOT_FOUND);
        }
        if (!self && settingsService.get(userId).isPrivate()) {
            return List.of();
        }
        return userSocialLinkRepository.findAllByUser_IdOrderByCreatedAtDesc(userId)
                .stream()
                .filter(l -> self || Boolean.TRUE.equals(l.getIsVisible()))
                .map(UserSocialLinkDto::from)
                .toList();
    }

    public UserSocialLinkDto upsertLink(UUID userId, SocialPlatform platform, UpsertUserSocialLinkRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new AppException("User not found", HttpStatus.NOT_FOUND));

        if (platform == SocialPlatform.CUSTOM && isBlank(request.label())) {
            throw new AppException("label is required for CUSTOM platform", HttpStatus.BAD_REQUEST);
        }

        UserSocialLink socialLink = userSocialLinkRepository.findByUser_IdAndPlatform(userId, platform)
                .orElseGet(UserSocialLink::new);

        boolean isNew = socialLink.getId() == null;
        if (isNew) {
            socialLink.setUser(user);
            socialLink.setPlatform(platform);
            socialLink.setCreatedAt(LocalDateTime.now());
        }

        socialLink.setHandle(request.handle().trim());
        socialLink.setLabel(platform == SocialPlatform.CUSTOM ? request.label() : null);
        socialLink.setIsVisible(request.isVisible() != null ? request.isVisible() : Boolean.TRUE);

        return UserSocialLinkDto.from(userSocialLinkRepository.save(socialLink));
    }

    private void ensureUserExists(UUID userId) {
        if (!userRepository.existsById(userId)) {
            throw new AppException("User not found", HttpStatus.NOT_FOUND);
        }
    }

    private boolean isBlank(String value) {
        return value == null || value.isBlank();
    }
}
