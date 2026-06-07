package com.apsconnect.api.user;

import java.util.List;
import java.util.UUID;

public record PersonDto(
        UUID id,
        String username,
        String initials,
        String name,
        String school,
        String detail,
        String city,
        String job,
        UserStatus currentStatus,
        String profilePicUrl,
        boolean online,
        List<String> tags
) {
}
