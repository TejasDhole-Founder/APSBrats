package com.apsconnect.api.community;

import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDateTime;
import java.util.UUID;

/** One message in a community's group chat: text, one photo, or both. */
@Getter
@Setter
@Entity
@Table(name = "community_messages")
public class CommunityMessage {
    @Id
    @GeneratedValue
    private UUID id;

    private UUID communityId;
    private UUID senderId;
    private String body = "";
    private String imageUrl;

    @Enumerated(EnumType.STRING)
    private ContentStatus status = ContentStatus.ACTIVE;

    private LocalDateTime createdAt = LocalDateTime.now();
}
