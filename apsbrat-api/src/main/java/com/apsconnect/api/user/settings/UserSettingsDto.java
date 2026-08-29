package com.apsconnect.api.user.settings;

public record UserSettingsDto(
        boolean showPhone,
        boolean batchmatesOnly,
        boolean discoverable
) {
    public static UserSettingsDto from(UserSettings s) {
        return new UserSettingsDto(
                Boolean.TRUE.equals(s.getShowPhone()),
                Boolean.TRUE.equals(s.getBatchmatesOnly()),
                !Boolean.FALSE.equals(s.getDiscoverable()));
    }

    public static UserSettingsDto defaults() {
        return new UserSettingsDto(false, false, true);
    }
}
