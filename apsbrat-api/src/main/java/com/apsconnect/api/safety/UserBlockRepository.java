package com.apsconnect.api.safety;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.UUID;

public interface UserBlockRepository extends JpaRepository<UserBlock, UUID> {

    boolean existsByBlocker_IdAndBlocked_Id(UUID blockerId, UUID blockedId);

    long deleteByBlocker_IdAndBlocked_Id(UUID blockerId, UUID blockedId);

    List<UserBlock> findAllByBlocker_IdOrderByCreatedAtDesc(UUID blockerId);

    @Query("""
            SELECT COUNT(b) > 0 FROM UserBlock b
            WHERE (b.blocker.id = :a AND b.blocked.id = :b)
               OR (b.blocker.id = :b AND b.blocked.id = :a)
            """)
    boolean existsBetween(@Param("a") UUID a, @Param("b") UUID b);

    @Query("""
            SELECT CASE WHEN b.blocker.id = :userId THEN b.blocked.id ELSE b.blocker.id END
            FROM UserBlock b
            WHERE b.blocker.id = :userId OR b.blocked.id = :userId
            """)
    List<UUID> findBlockedIdsInvolving(@Param("userId") UUID userId);
}
