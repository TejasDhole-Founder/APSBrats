package com.apsconnect.api.user;

/** Result of a pre-registration uniqueness check. {@code message} is null when available. */
public record AvailabilityDto(boolean available, String message) {

    static AvailabilityDto ok() {
        return new AvailabilityDto(true, null);
    }

    static AvailabilityDto no(String message) {
        return new AvailabilityDto(false, message);
    }
}
