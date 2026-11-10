package com.apsconnect.api.community;

import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.io.Serializable;
import java.time.LocalDateTime;
import java.util.UUID;

/** One person's answer to an event: Going or Interested. No row = no answer. */
@Getter
@Setter
@Entity
@Table(name = "event_rsvps")
@IdClass(EventRsvp.Key.class)
public class EventRsvp {

    public enum Status { GOING, INTERESTED }

    @Id
    private UUID eventId;

    @Id
    private UUID userId;

    @Enumerated(EnumType.STRING)
    private Status status;

    private LocalDateTime createdAt = LocalDateTime.now();

    @EqualsAndHashCode
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Key implements Serializable {
        private UUID eventId;
        private UUID userId;
    }
}
