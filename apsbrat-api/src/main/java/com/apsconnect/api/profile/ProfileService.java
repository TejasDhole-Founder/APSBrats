package com.apsconnect.api.profile;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.connection.ConnectionRepository;
import com.apsconnect.api.connection.ConnectionStatus;
import com.apsconnect.api.safety.UserBlockRepository;
import com.apsconnect.api.user.User;
import com.apsconnect.api.user.UserRepository;
import com.apsconnect.api.user.history.UserSchoolHistoryService;
import com.apsconnect.api.user.settings.UserSettingsDto;
import com.apsconnect.api.user.settings.UserSettingsService;
import com.apsconnect.api.user.social.UserSocialLinkDto;
import com.apsconnect.api.user.social.UserSocialLinkRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class ProfileService {

    private final UserRepository userRepository;
    private final UserSchoolHistoryService historyService;
    private final UserSocialLinkRepository socialLinkRepository;
    private final ConnectionRepository connectionRepository;
    private final UserBlockRepository blockRepository;
    private final UserSettingsService settingsService;

    @Transactional(readOnly = true)
    public ProfileDto getByUsername(UUID viewerId, String username) {
        User user = userRepository.findByUsername(username)
                .filter(u -> u.getDeletedAt() == null)
                .orElseThrow(() -> new AppException("Profile not found", HttpStatus.NOT_FOUND));

        boolean self = user.getId().equals(viewerId);
        if (!self && blockRepository.existsBetween(viewerId, user.getId())) {
            throw new AppException("Profile not found", HttpStatus.NOT_FOUND);
        }

        UserSettingsDto settings = settingsService.get(user.getId());
        boolean connected = self || isConnected(viewerId, user.getId());
        boolean restricted = !self && settings.batchmatesOnly() && !connected;

        long connectedCount = connectionRepository.countAcceptedForUser(user.getId());

        if (restricted) {
            return new ProfileDto(
                    user.getId(),
                    user.getUsername(),
                    user.getFullName(),
                    null, null, null, null,
                    user.getProfilePicUrl(),
                    Boolean.TRUE.equals(user.getIsVerified()),
                    user.getCurrentStatus(),
                    List.of(),
                    List.of(),
                    connectedCount,
                    0,
                    connectedCount,
                    true
            );
        }

        List<SchoolHistoryDto> schools = historyService.getSchoolHistory(user.getId());

        List<UserSocialLinkDto> socials = socialLinkRepository
                .findAllByUser_IdOrderByCreatedAtDesc(user.getId()).stream()
                .filter(s -> Boolean.TRUE.equals(s.getIsVisible()))
                .map(UserSocialLinkDto::from)
                .toList();

        String phone = self || (settings.showPhone() && connected) ? user.getPhone() : null;

        return new ProfileDto(
                user.getId(),
                user.getUsername(),
                user.getFullName(),
                user.getBio(),
                user.getCity(),
                user.getProfession(),
                phone,
                user.getProfilePicUrl(),
                Boolean.TRUE.equals(user.getIsVerified()),
                user.getCurrentStatus(),
                schools,
                socials,
                connectedCount,
                schools.size(),
                connectedCount,
                false
        );
    }

    private boolean isConnected(UUID a, UUID b) {
        return connectionRepository.findBetween(a, b).stream()
                .anyMatch(c -> c.getStatus() == ConnectionStatus.ACCEPTED);
    }
}
