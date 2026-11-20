package com.apsconnect.api.email;

import lombok.Getter;

/**
 * The provider did not accept an email. {@link #getReason()} is a short, safe
 * sentence for operators (never the provider's raw reply, never the recipient);
 * {@link #getProviderStatus()} is the HTTP status, or 0 when it was never reached.
 */
@Getter
public class EmailSendException extends RuntimeException {

    private final String reason;
    private final int providerStatus;

    public EmailSendException(String reason, int providerStatus) {
        super(reason);
        this.reason = reason;
        this.providerStatus = providerStatus;
    }
}
