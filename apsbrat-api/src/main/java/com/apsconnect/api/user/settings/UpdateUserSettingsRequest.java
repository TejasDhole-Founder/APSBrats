package com.apsconnect.api.user.settings;

/** Any null field is left unchanged. */
public record UpdateUserSettingsRequest(
        Boolean isPrivate,
        Boolean discoverable,
        Boolean showActivity
) {
}
