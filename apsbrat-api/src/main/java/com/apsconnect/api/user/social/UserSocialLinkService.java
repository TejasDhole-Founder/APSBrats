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

    public List<UserSocialLinkDto> getLinks(UUID userId) {
        ensureUserExists(userId);
        return userSocialLinkRepository.findAllByUser_IdOrderByCreatedAtDesc(userId)
                .stream()
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
        return value == null || value.trim().isEmpty();
    }
}
