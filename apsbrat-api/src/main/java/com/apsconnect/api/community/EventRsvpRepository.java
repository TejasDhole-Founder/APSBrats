package com.apsconnect.api.community;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

public interface EventRsvpRepository extends JpaRepository<EventRsvp, EventRsvp.Key> {

    /** Rows of (eventId, status, count) for these events. */
    @Query("SELECT r.eventId, r.status, COUNT(r) FROM EventRsvp r WHERE r.eventId IN :eventIds GROUP BY r.eventId, r.status")
    List<Object[]> countByEvent(@Param("eventIds") Collection<UUID> eventIds);

    List<EventRsvp> findByUserIdAndEventIdIn(UUID userId, Collection<UUID> eventIds);

    List<EventRsvp> findByEventIdOrderByCreatedAtAsc(UUID eventId);
}
