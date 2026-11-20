package com.apsconnect.api.email;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

import java.time.Duration;

/**
 * Brevo transactional email settings (application.yml {@code app.email}).
 * The key and the sender come from the environment; both blank means email is
 * not configured and nothing is ever sent.
 */
@Getter
@Setter
@Component
@ConfigurationProperties(prefix = "app.email")
public class EmailProperties {

    /** BREVO_API_KEY. Never logged, never returned by any endpoint. */
    private String apiKey = "";
    private String baseUrl = "https://api.brevo.com/v3";
    /** EMAIL_SENDER_ADDRESS: must be a sender (or domain) verified in the Brevo account. */
    private String senderAddress = "";
    private String senderName = "APS Brats";
    private Duration connectTimeout = Duration.ofSeconds(3);
    private Duration readTimeout = Duration.ofSeconds(8);

    public boolean hasApiKey() {
        return apiKey != null && !apiKey.isBlank();
    }

    public boolean hasSender() {
        return senderAddress != null && !senderAddress.isBlank();
    }

    public boolean isConfigured() {
        return hasApiKey() && hasSender();
    }
}
