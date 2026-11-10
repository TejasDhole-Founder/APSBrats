package com.apsconnect.api.community;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record CreateCommunityRequest(
        @NotBlank(message = "name is required")
        @Size(min = 3, max = 60, message = "name must be 3 to 60 characters")
        String name,

        @Size(max = 500, message = "description must be at most 500 characters")
        String description,

        @NotNull(message = "visibility is required (OPEN or PRIVATE)")
        CommunityVisibility visibility
) {
}
