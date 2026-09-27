package com.apsconnect.api.circle;

/** The numbers on the people screen header and the bell badge. */
public record CircleSummaryDto(
        long friends,
        long incomingRequests,
        long sentRequests,
        long classmates,
        long schoolmates,
        /** False when none of my school entries has a section, so classmates can't be matched. */
        boolean hasSection
) {
}
