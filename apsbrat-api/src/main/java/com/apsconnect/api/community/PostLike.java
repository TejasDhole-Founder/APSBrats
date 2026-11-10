package com.apsconnect.api.community;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.io.Serializable;
import java.time.LocalDateTime;
import java.util.UUID;

/** One row = this person liked this post. The pair of ids is the key, so a double like is impossible. */
@Getter
@Setter
@Entity
@Table(name = "post_likes")
@IdClass(PostLike.Key.class)
public class PostLike {
    @Id
    private UUID postId;

    @Id
    private UUID userId;

    private LocalDateTime createdAt = LocalDateTime.now();

    @EqualsAndHashCode
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Key implements Serializable {
        private UUID postId;
        private UUID userId;
    }
}