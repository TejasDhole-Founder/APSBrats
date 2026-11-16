package com.apsconnect.api.connection;

import java.time.LocalDateTime;
import java.util.UUID;

/** One entry of a relationship's history, as the app sees it. */
public record ConnectionEventDto(
        UUID id,
        ConnectionEventType type,
        /** Who did it; null when unknown. */
        UUID actorId,
        LocalDateTime createdAt
) {
    static ConnectionEventDto from(ConnectionEvent e) {
        return new ConnectionEventDto(e.getId(), e.getEventType(), e.getActorId(), e.getCreatedAt());
    }
}
