package com.apsconnect.api.connection;

import com.apsconnect.api.user.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.JdbcType;
import org.hibernate.dialect.PostgreSQLEnumJdbcType;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * The relationship between two users. There is exactly one row per pair
 * ({@link #userLowId}, {@link #userHighId}, see {@link UserPair}); requester and addressee
 * say who sent the current (latest) request.
 */
@Getter
@Setter
@Entity
@Table(name = "connections")
public class Connection {
    @Id
    @GeneratedValue
    private UUID id;

    /** The smaller of the two user ids (see {@link UserPair}). Never changes. */
    @Column(name = "user_low_id", nullable = false, updatable = false)
    private UUID userLowId;

    /** The larger of the two user ids. Never changes. */
    @Column(name = "user_high_id", nullable = false, updatable = false)
    private UUID userHighId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "requester_id", nullable = false)
    private User requester;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "addressee_id", nullable = false)
    private User addressee;

    @Enumerated(EnumType.STRING)
    @JdbcType(PostgreSQLEnumJdbcType.class)
    @Column(nullable = false, columnDefinition = "connection_status")
    private ConnectionStatus status;

    /** The first time this pair ever connected. Kept when the pair re-requests later. */
    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    /** When the latest request was sent. */
    @Column(name = "requested_at", nullable = false)
    private LocalDateTime requestedAt;

    /** Set when the addressee accepts; cleared if the pair is re-requested later. */
    @Column(name = "accepted_at")
    private LocalDateTime acceptedAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @Version
    @Column(nullable = false)
    private Long version;

    /** A new row for [requester] asking [addressee], with the pair columns in canonical order. */
    static Connection newRequest(User requester, User addressee) {
        UserPair pair = UserPair.of(requester.getId(), addressee.getId());
        Connection c = new Connection();
        c.userLowId = pair.low();
        c.userHighId = pair.high();
        c.requester = requester;
        c.addressee = addressee;
        c.status = ConnectionStatus.PENDING;
        c.requestedAt = LocalDateTime.now();
        return c;
    }

    @PrePersist
    void onCreate() {
        LocalDateTime now = LocalDateTime.now();
        if (createdAt == null) {
            createdAt = now;
        }
        if (requestedAt == null) {
            requestedAt = now;
        }
        if (status == null) {
            status = ConnectionStatus.PENDING;
        }
        if (updatedAt == null) {
            updatedAt = now;
        }
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
