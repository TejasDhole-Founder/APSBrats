package com.apsconnect.api.user;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;

/** Fields a user may change on their own profile. Phone is the login credential and is not editable here. */
public record UpdateProfileRequest(
        @NotBlank(message = "fullName is required")
        @Size(max = 100, message = "fullName must be at most 100 characters")
        String fullName,

        @NotBlank(message = "username is required")
        @Size(max = 50, message = "username must be at most 50 characters")
        String username,

        @Size(max = 100, message = "email must be at most 100 characters")
        String email,

        @Size(max = 100, message = "city must be at most 100 characters")
        String city,

        @Size(max = 150, message = "profession must be at most 150 characters")
        String profession,

        @Size(max = 20, message = "gender must be at most 20 characters")
        String gender,

        LocalDate dob,

        @Size(max = 500, message = "bio must be at most 500 characters")
        String bio,

        UserStatus currentStatus
) {
}
