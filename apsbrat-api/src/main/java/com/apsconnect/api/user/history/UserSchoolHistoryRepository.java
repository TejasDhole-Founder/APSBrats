package com.apsconnect.api.user.history;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface UserSchoolHistoryRepository extends JpaRepository<UserSchoolHistory, UUID> {
    void deleteAllByUser_Id(UUID userId);
}
