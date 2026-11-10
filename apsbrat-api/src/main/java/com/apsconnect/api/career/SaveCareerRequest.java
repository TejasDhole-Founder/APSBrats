package com.apsconnect.api.career;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;
import java.util.UUID;

public record SaveCareerRequest(
        @NotNull(message = "kind is required")
        CareerKind kind,

        /** Picked from the autocomplete list. */
        UUID organizationId,

        /** Typed when the company or college wasn't in the list. One of the two is required. */
        @Size(max = 200, message = "organizationName must be at most 200 characters")
        String organizationName,

        /** Job title for WORK, degree for EDUCATION. */
        @NotBlank(message = "title is required")
        @Size(max = 150, message = "title must be at most 150 characters")
        String title,

        @Size(max = 100, message = "fieldOfStudy must be at most 100 characters")
        String fieldOfStudy,

        @Size(max = 120, message = "location must be at most 120 characters")
        String location,

        @Size(max = 1000, message = "description must be at most 1000 characters")
        String description,

        @NotNull(message = "startDate is required")
        LocalDate startDate,

        /** Null means "still here". */
        LocalDate endDate,

        Boolean isHidden
) {
}