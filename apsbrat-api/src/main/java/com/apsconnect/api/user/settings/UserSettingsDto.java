package com.apsconnect.api.user.settings;

public record UserSettingsDto(
        boolean isPrivate,
        boolean discoverable,
        boolean showActivity
) {
    public static UserSettingsDto from(UserSettings s) {
        return new UserSettingsDto(
                Boolean.TRUE.equals(s.getIsPrivate()),
                !Boolean.FALSE.equals(s.getDiscoverable()),
                !Boolean.FALSE.equals(s.getShowActivity()));
    }

    public static UserSettingsDto defaults() {
        return new UserSettingsDto(false, true, true);
    }
}
