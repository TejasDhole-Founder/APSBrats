package com.apsconnect.api.user.settings;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDateTime;
import java.util.UUID;

@Getter
@Setter
@Entity
@Table(name = "user_settings")
public class UserSettings {

    @Id
    @Column(name = "user_id")
    private UUID userId;

    /** Private = other users cannot see this person's phone number or social links. */
    @Column(name = "is_private", nullable = false)
    private Boolean isPrivate;

    @Column(nullable = false)
    private Boolean discoverable;

    /** Others see "Active now / 2h ago". Off also hides everyone else's from me. */
    @Column(nullable = false)
    private Boolean showActivity;

    @Column(nullable = false)
    private LocalDateTime createdAt;

    @Column(nullable = false)
    private LocalDateTime updatedAt;

    @PrePersist
    void onCreate() {
        LocalDateTime now = LocalDateTime.now();
        if (createdAt == null) {
            createdAt = now;
        }
        if (updatedAt == null) {
            updatedAt = now;
        }
        if (isPrivate == null) {
            isPrivate = Boolean.FALSE;
        }
        if (discoverable == null) {
            discoverable = Boolean.TRUE;
        }
        if (showActivity == null) {
            showActivity = Boolean.TRUE;
        }
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
