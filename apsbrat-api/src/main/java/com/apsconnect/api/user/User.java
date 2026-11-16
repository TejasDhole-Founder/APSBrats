package com.apsconnect.api.user;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.JdbcType;
import org.hibernate.dialect.PostgreSQLEnumJdbcType;

import java.math.BigDecimal;
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

    /** Null until the onboarding profile step runs — a bare account exists from the moment the email is verified. */
    @Column(unique = true)
    private String username;

    private String fullName;

    /** Legacy contact field. No longer collected at signup and never used for login. */
    @Column(unique = true)
    private String phone;

    /** The login identity — email + OTP, or Google via Firebase, both resolve here. */
    @Column(nullable = false, unique = true)
    private String email;

    @Column(name = "password_hash")
    private String passwordHash;

    private LocalDate dob;
    private String profilePicUrl;
    private String bio;
    private String city;
    private String state;
    private String country;

    /** Coordinates from the phone, rounded before they are saved. */
    @Column(precision = 9, scale = 6)
    private BigDecimal latitude;

    @Column(precision = 9, scale = 6)
    private BigDecimal longitude;

    /** Provider place id for the chosen city, so the same place always matches. */
    @Column(name = "place_id", length = 64)
    private String placeId;

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

    /** Written only by PresenceService (a direct UPDATE), so saving a User never overwrites it. */
    @Column(name = "last_active_at", insertable = false, updatable = false)
    private LocalDateTime lastActiveAt;

    @Version
    @Column(nullable = false)
    private Long version;

    /**
     * Basic onboarding is done: the profile step saved a name and a username. (That
     * save also requires a valid date of birth, so the age check is covered; older
     * accounts without one aren't locked out.) Schools, career and socials are optional.
     */
    public boolean isOnboarded() {
        return fullName != null && fullName.trim().length() >= 2
                && username != null && !username.isBlank();
    }

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
