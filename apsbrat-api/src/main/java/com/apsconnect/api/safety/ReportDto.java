package com.apsconnect.api.safety;

import java.time.LocalDateTime;
import java.util.UUID;

public record ReportDto(
        UUID id,
        UUID reporterId,
        UUID targetUserId,
        ReportTargetType targetType,
        UUID targetId,
        String reason,
        String details,
        String status,
        LocalDateTime createdAt
) {
    public static ReportDto from(Report r) {
        return new ReportDto(
                r.getId(),
                r.getReporter() != null ? r.getReporter().getId() : null,
                r.getTargetUser() != null ? r.getTargetUser().getId() : null,
                r.getTargetType(),
                r.getTargetId(),
                r.getReason(),
                r.getDetails(),
                r.getStatus(),
                r.getCreatedAt()
        );
    }
}
