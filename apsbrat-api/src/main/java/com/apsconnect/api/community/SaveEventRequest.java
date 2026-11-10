package com.apsconnect.api.community;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDateTime;

/** Create or edit an event. Start and end are both required; description and coverUrl are optional. */
public record SaveEventRequest(
        @NotBlank(message = "Give the event a title")
        @Size(max = 120, message = "Title can be at most 120 characters")
        String title,

        @Size(max = 2000, message = "Details can be at most 2000 characters")
        String description,

        @NotBlank(message = "Where is it? Add a venue, or write Online")
        @Size(max = 200, message = "Venue can be at most 200 characters")
        String venue,

        @NotNull(message = "Pick a date and time")
        LocalDateTime startsAt,

        @NotNull(message = "Pick an end date and time")
        LocalDateTime endsAt,

        @Size(max = 300, message = "Invalid photo")
        String coverUrl
) {
}
