package com.apsconnect.api.common.realtime;

import com.fasterxml.jackson.databind.JsonNode;

public record RealtimeMessage(
        String kind,
        String target,
        JsonNode payload
) {
    public static final String KIND_DM = "DM";
    public static final String KIND_COMMUNITY = "COMMUNITY";
}
