package com.apsconnect.api.user.history;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.NotNull;

import java.util.UUID;

public record SaveSchoolHistoryItemRequest(
        @NotNull(message = "schoolId is required")
        UUID schoolId,

        @NotNull(message = "classFrom is required")
        @Min(value = 1, message = "classFrom must be >= 1")
        @Max(value = 12, message = "classFrom must be <= 12")
        Short classFrom,

        @NotNull(message = "classTo is required")
        @Min(value = 1, message = "classTo must be >= 1")
        @Max(value = 12, message = "classTo must be <= 12")
        Short classTo,

        /** Section letter, optional. Class number is never part of it ("D", not "12D"). */
        @Pattern(regexp = "^[A-Za-z]{1,2}$", message = "section must be a letter like A or B")
        String section,

        @NotNull(message = "batchStart is required")
        @Min(value = 1900, message = "batchStart must be valid year")
        @Max(value = 2200, message = "batchStart must be valid year")
        Short batchStart,

        @NotNull(message = "batchEnd is required")
        @Min(value = 1900, message = "batchEnd must be valid year")
        @Max(value = 2200, message = "batchEnd must be valid year")
        Short batchEnd,

        /** Required when classTo is 11 or 12, must be absent otherwise. */
        Stream stream,

        Boolean isPrimary
) {
}
