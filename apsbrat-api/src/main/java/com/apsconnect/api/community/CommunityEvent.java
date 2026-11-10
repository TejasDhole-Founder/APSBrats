package com.apsconnect.api.community;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDateTime;
import java.util.UUID;

/** A reunion or meetup in a community. Times are local wall-clock time. */
@Getter
@Setter
@Entity
@Table(name = "community_events")
public class CommunityEvent {
    @Id
    @GeneratedValue
    private UUID id;

    private UUID communityId;
    private UUID organizerId;
    private String title;
    private String description;
    private String venue;
    private LocalDateTime startsAt;
    private LocalDateTime endsAt;
    private String coverUrl;
    private boolean cancelled;
    private LocalDateTime createdAt = LocalDateTime.now();
}
