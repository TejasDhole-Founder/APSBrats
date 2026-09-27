package com.apsconnect.api.notification;

import com.apsconnect.api.user.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.JdbcType;
import org.hibernate.dialect.PostgreSQLEnumJdbcType;

import java.time.LocalDateTime;
import java.util.UUID;

@Getter
@Setter
@Entity
@Table(name = "notifications")
public class Notification {
    @Id
    @GeneratedValue
    private UUID id;

    /** Who receives it. */
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    /** Who it is about (the requester, the accepter, the joiner). Null for system notices. */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "actor_id")
    private User actor;

    @Enumerated(EnumType.STRING)
    @JdbcType(PostgreSQLEnumJdbcType.class)
    @Column(nullable = false, columnDefinition = "notification_type")
    private NotificationType type;

    @Column(nullable = false)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String body;

    /** What to open / act on. Plain text column, not a Postgres enum. */
    @Enumerated(EnumType.STRING)
    @Column(name = "ref_type", length = 30)
    private NotificationRef refType;

    @Column(name = "ref_id")
    private UUID refId;

    /** Collapses repeats, e.g. "JOIN:school:<id>:2026-09-15" for "3 new people joined". */
    @Column(name = "group_key", length = 120)
    private String groupKey;

    @Column(name = "is_read", nullable = false)
    private boolean read;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = LocalDateTime.now();
        }
    }
}
