package com.apsconnect.api.connection;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface ConnectionEventRepository extends JpaRepository<ConnectionEvent, UUID> {

    /** Oldest first, so the list reads like a story. The id breaks ties between events in the same instant. */
    List<ConnectionEvent> findByConnectionIdOrderByCreatedAtAscIdAsc(UUID connectionId, Pageable page);
}
