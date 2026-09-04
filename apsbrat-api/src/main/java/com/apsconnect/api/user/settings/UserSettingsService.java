package com.apsconnect.api.user.settings;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class UserSettingsService {

    private final UserSettingsRepository repository;

    @Transactional(readOnly = true)
    public UserSettingsDto get(UUID userId) {
        return repository.findById(userId)
                .map(UserSettingsDto::from)
                .orElseGet(UserSettingsDto::defaults);
    }

    @Transactional
    public UserSettingsDto update(UUID userId, UpdateUserSettingsRequest request) {
        UserSettings settings = repository.findById(userId).orElseGet(() -> {
            UserSettings s = new UserSettings();
            s.setUserId(userId);
            return s;
        });
        if (request.showPhone() != null) {
            settings.setShowPhone(request.showPhone());
        }
        if (request.batchmatesOnly() != null) {
            settings.setBatchmatesOnly(request.batchmatesOnly());
        }
        if (request.discoverable() != null) {
            settings.setDiscoverable(request.discoverable());
        }
        return UserSettingsDto.from(repository.save(settings));
    }

    @Transactional(readOnly = true)
    public Map<UUID, UserSettingsDto> forUsers(Collection<UUID> userIds) {
        if (userIds == null || userIds.isEmpty()) {
            return Map.of();
        }
        List<UserSettings> found = repository.findAllByUserIdIn(userIds);
        return found.stream().collect(Collectors.toMap(UserSettings::getUserId, UserSettingsDto::from,
                (a, b) -> a));
    }
}
