package com.apsconnect.api.user.settings;

public record UpdateUserSettingsRequest(
        Boolean showPhone,
        Boolean batchmatesOnly,
        Boolean discoverable
) {
}
