package com.apsconnect.api.user.settings;

public record UserSettingsDto(
        boolean isPrivate,
        boolean discoverable
) {
    public static UserSettingsDto from(UserSettings s) {
        return new UserSettingsDto(
                Boolean.TRUE.equals(s.getIsPrivate()),
                !Boolean.FALSE.equals(s.getDiscoverable()));
    }

    public static UserSettingsDto defaults() {
        return new UserSettingsDto(false, true);
    }
}
