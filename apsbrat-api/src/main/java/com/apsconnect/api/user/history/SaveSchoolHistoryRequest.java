package com.apsconnect.api.user.history;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;

import java.util.List;

public record SaveSchoolHistoryRequest(
        @NotEmpty(message = "items must not be empty")
        List<@Valid SaveSchoolHistoryItemRequest> items
) {
}
