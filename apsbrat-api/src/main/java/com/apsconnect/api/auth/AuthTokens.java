package com.apsconnect.api.auth;

import com.apsconnect.api.user.UserDto;

public record AuthTokens(
        String accessToken,
        String refreshToken,
        UserDto user
) {
}
