package com.apsconnect.api.email;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.time.Instant;

/**
 * What the admin health check reports. Contains no secret: the key is only
 * described as set or not, and valid or not.
 *
 * @param status        UP, DEGRADED (key works, sender not verified), DOWN or NOT_CONFIGURED
 * @param apiKeyValid   null when it was not checked (not configured)
 * @param senderVerified null when Brevo could not list senders
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record EmailHealth(
        String status,
        String provider,
        boolean apiKeySet,
        boolean senderSet,
        Boolean apiKeyValid,
        Boolean senderVerified,
        String sender,
        Long latencyMs,
        String detail,
        Instant checkedAt) {
}
