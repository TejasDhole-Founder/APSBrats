package com.apsconnect.api.profile;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.connection.ConnectionRepository;
import com.apsconnect.api.safety.UserBlockRepository;
import com.apsconnect.api.user.PersonService;
import com.apsconnect.api.user.PresenceService;
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
    private final PersonService personService;
    private final PresenceService presenceService;

    @Transactional(readOnly = true)
    public ProfileDto getById(UUID viewerId, UUID userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new AppException("Profile not found", HttpStatus.NOT_FOUND));

        // A deleted account: their posts and messages stay under their name, but
        // opening the profile shows no details (the app says "Unknown user").
        if (user.getDeletedAt() != null) {
            return new ProfileDto(user.getId(), null, user.getFullName(), null, null, null, null, null,
                    false, null, List.of(), List.of(), 0, 0, 0, 0, false, null, true);
        }

        boolean self = user.getId().equals(viewerId);
        if (!self && blockRepository.existsBetween(viewerId, user.getId())) {
            throw new AppException("Profile not found", HttpStatus.NOT_FOUND);
        }

        // Name, schools, city, profession, bio are always visible — that is the
        // point of the app. A Private profile only hides phone and socials
        // from everyone except the owner.
        UserSettingsDto settings = settingsService.get(user.getId());
        boolean hideContact = !self && settings.isPrivate();

        long connectedCount = connectionRepository.countAcceptedForUser(user.getId());
        int mutualCount = self ? 0 : personService.mutualCounts(viewerId, List.of(user.getId()))
                .getOrDefault(user.getId(), 0);
        List<SchoolHistoryDto> schools = historyService.getSchoolHistory(user.getId());

        List<UserSocialLinkDto> socials = hideContact
                ? List.of()
                : socialLinkRepository.findAllByUser_IdOrderByCreatedAtDesc(user.getId()).stream()
                        .filter(s -> Boolean.TRUE.equals(s.getIsVisible()))
                        .map(UserSocialLinkDto::from)
                        .toList();

        return new ProfileDto(
                user.getId(),
                user.getUsername(),
                user.getFullName(),
                user.getBio(),
                user.getCity(),
                user.getProfession(),
                hideContact ? null : user.getPhone(),
                user.getProfilePicUrl(),
                Boolean.TRUE.equals(user.getIsVerified()),
                user.getCurrentStatus(),
                schools,
                socials,
                connectedCount,
                schools.size(),
                connectedCount,
                mutualCount,
                settings.isPrivate(),
                presenceService.visibleLastActive(viewerId, List.of(user)).get(user.getId()),
                false
        );
    }
}
