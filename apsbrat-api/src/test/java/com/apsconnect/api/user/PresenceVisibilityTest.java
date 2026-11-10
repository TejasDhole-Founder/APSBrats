package com.apsconnect.api.user;

import com.apsconnect.api.user.settings.UserSettingsDto;
import com.apsconnect.api.user.settings.UserSettingsService;
import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class PresenceVisibilityTest {

    private final UUID viewer = UUID.randomUUID();
    private final User shown = user();
    private final User hidden = user();
    private final UserSettingsService settings = mock(UserSettingsService.class);
    private final PresenceService presence = new PresenceService(null, settings, null);

    private static User user() {
        User u = new User();
        u.setId(UUID.randomUUID());
        u.setLastActiveAt(LocalDateTime.now().minusMinutes(2));
        return u;
    }

    private void viewerShows(boolean on) {
        when(settings.forUsers(any())).thenReturn(Map.of(
                viewer, new UserSettingsDto(false, true, on),
                hidden.getId(), new UserSettingsDto(false, true, false)));
    }

    @Test
    void onlyPeopleWhoShareTheirActivityAreShown() {
        viewerShows(true);
        assertThat(presence.visibleLastActive(viewer, List.of(shown, hidden)))
                .containsOnlyKeys(shown.getId());
        assertThat(PresenceService.isOnline(shown.getLastActiveAt())).isTrue();
    }

    @Test
    void hidingMineHidesEveryoneElsesFromMe() {
        viewerShows(false);
        assertThat(presence.visibleLastActive(viewer, List.of(shown, hidden))).isEmpty();
    }

    @Test
    void noViewerSeesNothing() {
        assertThat(presence.visibleLastActive(null, List.of(shown))).isEmpty();
    }

    @Test
    void activeTenMinutesAgoIsNotOnline() {
        assertThat(PresenceService.isOnline(LocalDateTime.now().minusMinutes(10))).isFalse();
        assertThat(PresenceService.isOnline(null)).isFalse();
    }
}
