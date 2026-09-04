package com.apsconnect.api.user;

import java.time.LocalDate;
import java.util.UUID;

public record UserDto(
        UUID id,
        String username,
        String fullName,
        String phone,
        String email,
        String city,
        String profession,
        String gender,
        LocalDate dob,
        String bio,
        String profilePicUrl,
        UserStatus currentStatus,
        boolean isVerified
) {
    public static UserDto from(User user) {
        return new UserDto(
                user.getId(),
                user.getUsername(),
                user.getFullName(),
                user.getPhone(),
                user.getEmail(),
                user.getCity(),
                user.getProfession(),
                user.getGender(),
                user.getDob(),
                user.getBio(),
                user.getProfilePicUrl(),
                user.getCurrentStatus(),
                Boolean.TRUE.equals(user.getIsVerified())
        );
    }
}
