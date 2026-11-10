package com.apsconnect.api.user;

import com.apsconnect.api.user.settings.UserSettingsDto;
import com.apsconnect.api.user.settings.UserSettingsService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * "Active now / 2h ago": last_active_at is bumped by any signed-in request (at
 * most once a minute), and is shown only when BOTH the person and the viewer
 * have "Show my activity" on.
 */
@Service
@RequiredArgsConstructor
public class PresenceService {

    /** Active within this window = online. */
    public static final Duration ONLINE_WINDOW = Duration.ofMinutes(5);

    private final UserRepository userRepository;
    private final UserSettingsService settingsService;
    private final StringRedisTemplate redis;

    /** At most one database write per person per minute (the Redis key is the throttle). */
    @Transactional
    public void touch(UUID userId) {
        Boolean first = redis.opsForValue().setIfAbsent("active:" + userId, "1", Duration.ofMinutes(1));
        if (Boolean.TRUE.equals(first)) {
            userRepository.touchLastActive(userId, LocalDateTime.now());
        }
    }

    /** Last-active times the viewer may see; no viewer, or a viewer who hides theirs, sees none. */
    public Map<UUID, LocalDateTime> visibleLastActive(UUID viewerId, Collection<User> users) {
        if (viewerId == null || users.isEmpty()) {
            return Map.of();
        }
        Set<UUID> ids = new HashSet<>();
        users.forEach(u -> ids.add(u.getId()));
        ids.add(viewerId);
        Map<UUID, UserSettingsDto> settings = settingsService.forUsers(ids);
        if (!shows(settings.get(viewerId))) {
            return Map.of();
        }
        Map<UUID, LocalDateTime> out = new HashMap<>();
        for (User u : users) {
            if (u.getLastActiveAt() != null && shows(settings.get(u.getId()))) {
                out.put(u.getId(), u.getLastActiveAt());
            }
        }
        return out;
    }

    public static boolean isOnline(LocalDateTime lastActiveAt) {
        return lastActiveAt != null && lastActiveAt.isAfter(LocalDateTime.now().minus(ONLINE_WINDOW));
    }

    /** No settings row = defaults = shown. */
    private static boolean shows(UserSettingsDto settings) {
        return settings == null || settings.showActivity();
    }
}
