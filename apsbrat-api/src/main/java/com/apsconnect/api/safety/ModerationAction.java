package com.apsconnect.api.safety;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDateTime;
import java.util.UUID;

@Getter
@Setter
@Entity
@Table(name = "moderation_actions")
public class ModerationAction {

    @Id
    @GeneratedValue
    private UUID id;

    @Column(name = "actor_id", nullable = false)
    private UUID actorId;

    @Column(name = "target_user_id")
    private UUID targetUserId;

    @Column(nullable = false, length = 40)
    private String action;

    @Column(length = 500)
    private String reason;

    @Column(name = "report_id")
    private UUID reportId;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = LocalDateTime.now();
        }
    }
}
