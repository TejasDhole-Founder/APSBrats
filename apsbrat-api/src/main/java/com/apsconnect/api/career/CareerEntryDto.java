package com.apsconnect.api.career;

import java.time.LocalDate;
import java.util.UUID;

public record CareerEntryDto(
        UUID id,
        CareerKind kind,
        UUID organizationId,
        String organizationName,
        String title,
        String fieldOfStudy,
        String location,
        String description,
        LocalDate startDate,
        LocalDate endDate,
        boolean isHidden
) {
    public static CareerEntryDto from(CareerEntry e) {
        return new CareerEntryDto(
                e.getId(),
                e.getKind(),
                e.getOrganization().getId(),
                e.getOrganization().getName(),
                e.getTitle(),
                e.getFieldOfStudy(),
                e.getLocation(),
                e.getDescription(),
                e.getStartDate(),
                e.getEndDate(),
                e.isHidden()
        );
    }
}