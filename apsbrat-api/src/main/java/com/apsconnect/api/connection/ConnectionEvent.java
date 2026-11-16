package com.apsconnect.api.connection;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.LocalDateTime;
import java.util.Map;
import java.util.UUID;

/** History of a relationship. The connections row holds the current state; this holds how it got there. */
@Getter
@Setter
@Entity
@Table(name = "connection_events")
public class ConnectionEvent {

    @Id
    @GeneratedValue
    private UUID id;

    @Column(name = "connection_id", nullable = false, updatable = false)
    private UUID connectionId;

    /** Who did it; null if that account no longer exists or the old data did not say. */
    @Column(name = "actor_id", updatable = false)
    private UUID actorId;

    @Enumerated(EnumType.STRING)
    @Column(name = "event_type", nullable = false, updatable = false, length = 20)
    private ConnectionEventType eventType;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    /** Extra detail for staff and debugging (e.g. why it happened). Never sent to the app. */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(columnDefinition = "jsonb", updatable = false)
    private Map<String, String> metadata;

    static ConnectionEvent of(UUID connectionId, UUID actorId, ConnectionEventType type,
                              LocalDateTime at, Map<String, String> metadata) {
        ConnectionEvent e = new ConnectionEvent();
        e.connectionId = connectionId;
        e.actorId = actorId;
        e.eventType = type;
        e.createdAt = at;
        e.metadata = metadata;
        return e;
    }
}
