package com.apsconnect.api.user;

import com.apsconnect.api.auth.AuthService;
import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.common.exception.ErrorCode;
import com.apsconnect.api.profile.SchoolHistoryDto;
import com.apsconnect.api.user.history.UserSchoolHistoryRepository;
import com.apsconnect.api.user.history.UserSchoolHistoryService;
import com.apsconnect.api.user.settings.UserSettingsService;
import com.apsconnect.api.user.social.UserSocialLinkDto;
import com.apsconnect.api.user.social.UserSocialLinkRepository;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AccountService {

    private static final Logger log = LoggerFactory.getLogger(AccountService.class);

    private final UserRepository userRepository;
    private final UserSchoolHistoryRepository historyRepository;
    private final UserSchoolHistoryService historyService;
    private final UserSocialLinkRepository socialLinkRepository;
    private final UserSettingsService settingsService;
    private final AuthService authService;

    @Transactional(readOnly = true)
    public AccountExportDto export(UUID userId) {
        User user = activeUser(userId);

        List<SchoolHistoryDto> schools = historyService.getSchoolHistory(userId);

        List<UserSocialLinkDto> socials = socialLinkRepository
                .findAllByUser_IdOrderByCreatedAtDesc(userId).stream()
                .map(UserSocialLinkDto::from)
                .toList();

        return new AccountExportDto(
                "APSBrats account export v1",
                LocalDateTime.now(),
                AccountExportDto.Profile.from(user),
                schools,
                socials,
                settingsService.get(userId)
        );
    }

    @Transactional
    public void deleteAccount(UUID userId) {
        User user = activeUser(userId);

        historyRepository.deleteAllByUser_Id(userId);
        socialLinkRepository.deleteAllByUser_Id(userId);

        String tombstone = "deleted_" + user.getId();
        user.setDeletedAt(LocalDateTime.now());
        user.setUsername(tombstone);
        user.setPhone(tombstone);
        user.setEmail(null);
        user.setFullName("Deleted user");
        user.setBio(null);
        user.setCity(null);
        user.setProfession(null);
        user.setGender(null);
        user.setDob(null);
        user.setProfilePicUrl(null);
        user.setWebsiteUrl(null);
        user.setFcmToken(null);
        user.setPasswordHash(null);
        user.setIsVerified(Boolean.FALSE);
        userRepository.save(user);

        authService.revokeAllFor(userId);
        log.info("Account soft-deleted and anonymized for userId={}", userId);
    }

    private User activeUser(UUID userId) {
        return userRepository.findById(userId)
                .filter(u -> u.getDeletedAt() == null)
                .orElseThrow(() -> new AppException("Account not found", HttpStatus.NOT_FOUND, ErrorCode.NOT_FOUND));
    }
}
