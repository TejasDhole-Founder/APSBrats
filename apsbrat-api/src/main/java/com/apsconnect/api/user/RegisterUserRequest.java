package com.apsconnect.api.user;

import java.time.LocalDate;

public record RegisterUserRequest(
        String username,
        String fullName,
        String phone,
        String email,
        LocalDate dob,
        String city,
        String profession,
        UserStatus currentStatus,
        String gender
) {
}
