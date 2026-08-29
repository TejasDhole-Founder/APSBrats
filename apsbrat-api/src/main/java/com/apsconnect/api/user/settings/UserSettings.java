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

    @Column(nullable = false)
    private Boolean showPhone;

    @Column(nullable = false)
    private Boolean batchmatesOnly;

    @Column(nullable = false)
    private Boolean discoverable;

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
        if (showPhone == null) {
            showPhone = Boolean.FALSE;
        }
        if (batchmatesOnly == null) {
            batchmatesOnly = Boolean.FALSE;
        }
        if (discoverable == null) {
            discoverable = Boolean.TRUE;
        }
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
