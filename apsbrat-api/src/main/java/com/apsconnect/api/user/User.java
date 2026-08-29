package com.apsconnect.api.user;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.JdbcType;
import org.hibernate.dialect.PostgreSQLEnumJdbcType;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

@Getter
@Setter
@Entity
@Table(name = "users")
public class User {
    @Id
    @GeneratedValue
    private UUID id;

    @Column(nullable = false, unique = true)
    private String username;

    @Column(nullable = false)
    private String fullName;

    @Column(nullable = false, unique = true)
    private String phone;

    @Column(unique = true)
    private String email;

    @Column(name = "password_hash")
    private String passwordHash;

    private LocalDate dob;
    private String profilePicUrl;
    private String bio;
    private String city;
    private String websiteUrl;

    @Enumerated(EnumType.STRING)
    @JdbcType(PostgreSQLEnumJdbcType.class)
    @Column(name = "current_status", columnDefinition = "user_status")
    private UserStatus currentStatus;

    private String profession;
    private String gender;
    private String fcmToken;
    private Boolean isVerified;

    @Enumerated(EnumType.STRING)
    @Column(name = "role", nullable = false, length = 20)
    private UserRole role;

    @Column(name = "suspended_until")
    private LocalDateTime suspendedUntil;

    @Column(name = "banned_at")
    private LocalDateTime bannedAt;

    @Column(nullable = false)
    private LocalDateTime createdAt;

    @Column(nullable = false)
    private LocalDateTime updatedAt;

    private LocalDateTime deletedAt;

    @Version
    @Column(nullable = false)
    private Long version;

    @PrePersist
    void onCreate() {
        LocalDateTime now = LocalDateTime.now();
        if (createdAt == null) {
            createdAt = now;
        }
        if (updatedAt == null) {
            updatedAt = now;
        }
        if (isVerified == null) {
            isVerified = Boolean.FALSE;
        }
        if (currentStatus == null) {
            currentStatus = UserStatus.STUDENT;
        }
        if (role == null) {
            role = UserRole.USER;
        }
    }

    public boolean isBanned() {
        return bannedAt != null;
    }

    public boolean isSuspended() {
        return suspendedUntil != null && suspendedUntil.isAfter(LocalDateTime.now());
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
