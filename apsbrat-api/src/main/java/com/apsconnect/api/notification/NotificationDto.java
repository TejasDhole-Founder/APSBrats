package com.apsconnect.api.notification;

import com.apsconnect.api.user.User;

import java.time.LocalDateTime;
import java.util.UUID;

public record NotificationDto(
        UUID id,
        NotificationType type,
        String title,
        String body,
        boolean read,
        LocalDateTime createdAt,
        /** Person the notification is about, for the avatar and the profile link. */
        UUID actorId,
        String actorName,
        String actorInitials,
        NotificationRef refType,
        UUID refId,
        /** True while a CONNECTION_REQUEST can still be accepted or declined. */
        boolean actionable
) {
    public static NotificationDto from(Notification n, boolean actionable) {
        User actor = n.getActor();
        return new NotificationDto(
                n.getId(), n.getType(), n.getTitle(), n.getBody(), n.isRead(), n.getCreatedAt(),
                actor == null ? null : actor.getId(),
                actor == null ? null : actor.getFullName(),
                actor == null ? null : initials(actor.getFullName()),
                n.getRefType(), n.getRefId(), actionable);
    }

    private static String initials(String fullName) {
        if (fullName == null || fullName.isBlank()) {
            return "?";
        }
        String[] parts = fullName.trim().split("\\s+");
        String first = parts[0].substring(0, 1);
        String last = parts.length > 1 ? parts[parts.length - 1].substring(0, 1) : "";
        return (first + last).toUpperCase();
    }
}
