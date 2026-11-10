package com.apsconnect.api.community;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDateTime;
import java.util.UUID;

/** A pending request to join a PRIVATE community. Deleted when approved or rejected. */
@Getter
@Setter
@Entity
@Table(name = "community_join_requests")
@IdClass(CommunityMember.Key.class)
public class JoinRequest {
    @Id
    private UUID communityId;

    @Id
    private UUID userId;

    private LocalDateTime createdAt = LocalDateTime.now();
}