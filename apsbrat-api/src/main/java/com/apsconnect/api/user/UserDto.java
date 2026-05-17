package com.apsconnect.api.user;

import java.util.UUID;

public record UserDto(
        UUID id,
        String username,
        String fullName,
        String phone,
        String email,
        String city,
        UserStatus currentStatus
) {
    public static UserDto from(User user) {
        return new UserDto(
                user.getId(),
                user.getUsername(),
                user.getFullName(),
                user.getPhone(),
                user.getEmail(),
                user.getCity(),
                user.getCurrentStatus()
        );
    }
}
