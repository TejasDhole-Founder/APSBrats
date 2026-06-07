package com.apsconnect.api.profile;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.connection.ConnectionRepository;
import com.apsconnect.api.user.User;
import com.apsconnect.api.user.UserRepository;
import com.apsconnect.api.user.history.UserSchoolHistory;
import com.apsconnect.api.user.history.UserSchoolHistoryRepository;
import com.apsconnect.api.user.social.UserSocialLinkDto;
import com.apsconnect.api.user.social.UserSocialLinkRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Comparator;
import java.util.List;

@Service
@RequiredArgsConstructor
public class ProfileService {

    private final UserRepository userRepository;
    private final UserSchoolHistoryRepository historyRepository;
    private final UserSocialLinkRepository socialLinkRepository;
    private final ConnectionRepository connectionRepository;

    @Transactional(readOnly = true)
    public ProfileDto getByUsername(String username) {
        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new AppException("Profile not found", HttpStatus.NOT_FOUND));

        List<SchoolHistoryDto> schools = historyRepository.findAllByUser_Id(user.getId()).stream()
                .sorted(Comparator.comparingInt((UserSchoolHistory h) -> h.getBatchEnd()).reversed())
                .map(SchoolHistoryDto::from)
                .toList();

        List<UserSocialLinkDto> socials = socialLinkRepository
                .findAllByUser_IdOrderByCreatedAtDesc(user.getId()).stream()
                .filter(s -> Boolean.TRUE.equals(s.getIsVisible()))
                .map(UserSocialLinkDto::from)
                .toList();

        long connected = connectionRepository.countAcceptedForUser(user.getId());

        return new ProfileDto(
                user.getId(),
                user.getUsername(),
                user.getFullName(),
                user.getBio(),
                user.getCity(),
                user.getProfession(),
                user.getProfilePicUrl(),
                Boolean.TRUE.equals(user.getIsVerified()),
                user.getCurrentStatus(),
                schools,
                socials,
                connected,
                schools.size(),
                connected
        );
    }
}
