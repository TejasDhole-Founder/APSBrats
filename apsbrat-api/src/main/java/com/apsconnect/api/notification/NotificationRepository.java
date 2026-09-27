package com.apsconnect.api.notification;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.UUID;

public interface NotificationRepository extends JpaRepository<Notification, UUID> {

    /** One page, newest first, actor loaded in the same query. */
    @EntityGraph(attributePaths = "actor")
    List<Notification> findAllByUser_IdOrderByCreatedAtDesc(UUID userId, Pageable pageable);

    long countByUser_IdAndReadFalse(UUID userId);

    @Modifying
    @Query("UPDATE Notification n SET n.read = true WHERE n.user.id = :userId AND n.read = false")
    void markAllRead(@Param("userId") UUID userId);
}
