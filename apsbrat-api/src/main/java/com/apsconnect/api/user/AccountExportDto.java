package com.apsconnect.api.user;

import com.apsconnect.api.profile.SchoolHistoryDto;
import com.apsconnect.api.user.settings.UserSettingsDto;
import com.apsconnect.api.user.social.UserSocialLinkDto;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

public record AccountExportDto(
        String exportFormat,
        LocalDateTime generatedAt,
        Profile profile,
        List<SchoolHistoryDto> schoolHistory,
        List<UserSocialLinkDto> socialLinks,
        UserSettingsDto settings
) {
    public record Profile(
            UUID id,
            String username,
            String fullName,
            String phone,
            String email,
            LocalDate dob,
            String bio,
            String city,
            String profession,
            String gender,
            String profilePicUrl,
            String websiteUrl,
            UserStatus currentStatus,
            boolean verified,
            LocalDateTime createdAt,
            LocalDateTime updatedAt
    ) {
        static Profile from(User u) {
            return new Profile(
                    u.getId(),
                    u.getUsername(),
                    u.getFullName(),
                    u.getPhone(),
                    u.getEmail(),
                    u.getDob(),
                    u.getBio(),
                    u.getCity(),
                    u.getProfession(),
                    u.getGender(),
                    u.getProfilePicUrl(),
                    u.getWebsiteUrl(),
                    u.getCurrentStatus(),
                    Boolean.TRUE.equals(u.getIsVerified()),
                    u.getCreatedAt(),
                    u.getUpdatedAt()
            );
        }
    }
}
