package com.apsconnect.api.community;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDateTime;
import java.util.UUID;

@Getter
@Setter
@Entity
@Table(name = "communities")
public class Community {
    @Id
    @GeneratedValue
    private UUID id;

    @Enumerated(EnumType.STRING)
    private CommunityType type;

    /** Set for SCHOOL communities only. */
    private UUID schoolId;

    private String name;

    /** Cleaned name used to keep INTEREST names unique (see career.NameKeys). */
    private String nameKey;

    private String description;

    @Enumerated(EnumType.STRING)
    private CommunityVisibility visibility = CommunityVisibility.OPEN;

    private UUID createdBy;
    private int memberCount;
    private LocalDateTime createdAt = LocalDateTime.now();

    @Version
    private Long version;
}