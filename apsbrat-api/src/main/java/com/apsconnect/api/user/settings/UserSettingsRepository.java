package com.apsconnect.api.user.settings;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

public interface UserSettingsRepository extends JpaRepository<UserSettings, UUID> {
    List<UserSettings> findAllByUserIdIn(Collection<UUID> userIds);
}
