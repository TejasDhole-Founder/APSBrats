package com.apsconnect.api.safety;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.UUID;

public record CreateReportRequest(
        @NotNull ReportTargetType targetType,
        UUID targetId,
        UUID targetUserId,
        @NotBlank @Size(max = 50) String reason,
        @Size(max = 2000) String details
) {
}
