package com.apsconnect.api.auth;

import jakarta.validation.constraints.NotBlank;

/** The Firebase ID token the app got back after the on-device Google sign-in. */
public record GoogleSignInRequest(
        @NotBlank(message = "idToken is required")
        String idToken
) {
}
