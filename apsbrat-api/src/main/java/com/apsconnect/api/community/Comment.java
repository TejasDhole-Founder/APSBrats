package com.apsconnect.api.community;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDateTime;
import java.util.UUID;

@Getter
@Setter
@Entity
@Table(name = "comments")
public class Comment {
    @Id
    @GeneratedValue
    private UUID id;

    private UUID postId;
    private UUID authorId;
    private String body;

    @Enumerated(EnumType.STRING)
    private ContentStatus status = ContentStatus.ACTIVE;

    private LocalDateTime createdAt = LocalDateTime.now();
}