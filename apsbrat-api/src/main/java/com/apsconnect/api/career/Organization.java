package com.apsconnect.api.career;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDateTime;
import java.util.UUID;

@Getter
@Setter
@Entity
@Table(name = "organizations")
public class Organization {
    @Id
    @GeneratedValue
    private UUID id;

    @Enumerated(EnumType.STRING)
    private OrgType type;

    private String name;
    private String nameKey;
    private String industry;
    private String website;

    /** UNVERIFIED (user-added) or VERIFIED (seeded or admin-approved). */
    private String status = "UNVERIFIED";

    private UUID createdBy;
    private LocalDateTime createdAt = LocalDateTime.now();
}