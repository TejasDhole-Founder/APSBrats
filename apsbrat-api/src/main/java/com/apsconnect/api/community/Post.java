package com.apsconnect.api.community;

import jakarta.persistence.*;
import lombok.Getter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import lombok.Setter;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Getter
@Setter
@Entity
@Table(name = "posts")
public class Post {
    @Id
    @GeneratedValue
    private UUID id;

    private UUID communityId;
    private UUID authorId;
    private String body;

    /** 0 to 10 photos, in the order they slide (addresses from POST /media/images). */
    @JdbcTypeCode(SqlTypes.ARRAY)
    @Column(name = "image_urls", columnDefinition = "text[]", nullable = false)
    private List<String> imageUrls = new ArrayList<>();

    @Enumerated(EnumType.STRING)
    private ContentStatus status = ContentStatus.ACTIVE;

    private int likeCount;
    private int commentCount;
    private LocalDateTime createdAt = LocalDateTime.now();

    /** null = not pinned. */
    private LocalDateTime pinnedAt;

    /** Shared from this event (its photos), or null. */
    private UUID eventId;

    /** A school memory: the year it's from and what it's about (both or neither). */
    private Short memoryYear;

    @Enumerated(EnumType.STRING)
    private MemoryCategory memoryCategory;

    @Version
    private Long version;
}