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
import java.util.regex.Pattern;

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
        validateHandle(platform, request.handle().trim());

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

    /** Removes one platform's link. Idempotent: nothing to remove is not an error. */
    public void deleteLink(UUID userId, SocialPlatform platform) {
        userSocialLinkRepository.findByUser_IdAndPlatform(userId, platform)
                .ifPresent(userSocialLinkRepository::delete);
    }

    /**
     * Checks that a handle looks like what its platform expects, so a typo is
     * caught at save time instead of showing up on someone's profile.
     */
    private void validateHandle(SocialPlatform platform, String handle) {
        Pattern pattern = switch (platform) {
            case INSTAGRAM -> INSTAGRAM_PATTERN;
            case LINKEDIN -> LINKEDIN_PATTERN;
            case WHATSAPP -> WHATSAPP_PATTERN;
            case TWITTER -> TWITTER_PATTERN;
            case CUSTOM -> CUSTOM_PATTERN;
        };
        if (!pattern.matcher(handle).matches()) {
            throw new AppException(
                    switch (platform) {
                        case INSTAGRAM -> "Enter a valid Instagram username or profile link";
                        case LINKEDIN -> "Enter a valid LinkedIn profile link";
                        case WHATSAPP -> "Enter a WhatsApp number with its country code, e.g. +91 98765 43210";
                        case TWITTER -> "Enter a valid X username or profile link";
                        case CUSTOM -> "Enter a valid web address, e.g. https://yoursite.dev";
                    },
                    HttpStatus.BAD_REQUEST);
        }
    }

    private static final Pattern INSTAGRAM_PATTERN = Pattern.compile(
            "^(@?[A-Za-z0-9._]{1,30}|(https?://)?(www\\.)?instagram\\.com/[A-Za-z0-9._]{1,30}/?)$",
            Pattern.CASE_INSENSITIVE);
    private static final Pattern LINKEDIN_PATTERN = Pattern.compile(
            "^(https?://)?(www\\.)?linkedin\\.com/(in|company)/[A-Za-z0-9\\-_%.]{2,100}/?$",
            Pattern.CASE_INSENSITIVE);
    /** Country code then the number, spaces or dashes allowed: +91 98765 43210. */
    private static final Pattern WHATSAPP_PATTERN = Pattern.compile(
            "^\\+\\d{1,4}[ -]?\\d[\\d -]{5,14}$");
    private static final Pattern TWITTER_PATTERN = Pattern.compile(
            "^(@?[A-Za-z0-9_]{1,15}|(https?://)?(www\\.)?(x|twitter)\\.com/[A-Za-z0-9_]{1,15}/?)$",
            Pattern.CASE_INSENSITIVE);
    private static final Pattern CUSTOM_PATTERN = Pattern.compile(
            "^(https?://)?[A-Za-z0-9-]+(\\.[A-Za-z0-9-]+)+(/\\S*)?$",
            Pattern.CASE_INSENSITIVE);

    private void ensureUserExists(UUID userId) {
        if (!userRepository.existsById(userId)) {
            throw new AppException("User not found", HttpStatus.NOT_FOUND);
        }
    }

    private boolean isBlank(String value) {
        return value == null || value.isBlank();
    }
}
