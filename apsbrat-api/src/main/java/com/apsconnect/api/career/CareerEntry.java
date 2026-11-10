package com.apsconnect.api.career;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

@Getter
@Setter
@Entity
@Table(name = "career_entries")
public class CareerEntry {
    @Id
    @GeneratedValue
    private UUID id;

    private UUID userId;

    @Enumerated(EnumType.STRING)
    private CareerKind kind;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "organization_id")
    private Organization organization;

    private UUID jobTitleId;

    /** Job title (WORK) or degree (EDUCATION). */
    private String title;

    private String fieldOfStudy;
    private String location;
    private String description;
    private LocalDate startDate;

    /** Null means "still here". */
    private LocalDate endDate;

    private boolean isHidden;
    private LocalDateTime createdAt = LocalDateTime.now();
}