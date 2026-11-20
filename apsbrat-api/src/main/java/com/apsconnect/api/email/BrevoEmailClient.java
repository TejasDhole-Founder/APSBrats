package com.apsconnect.api.email;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestClientResponseException;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * The only class that talks to Brevo's REST API (https://developers.brevo.com):
 * send a transactional email, and check that the key and sender are usable.
 * Short timeouts, so a slow provider never ties up a request thread for long.
 */
@Component
public class BrevoEmailClient {

    private static final Logger log = LoggerFactory.getLogger(BrevoEmailClient.class);
    private static final String PROVIDER = "brevo";

    private final EmailProperties props;
    private final RestClient http;

    @Autowired
    public BrevoEmailClient(EmailProperties props) {
        this(props, RestClient.builder().requestFactory(timeouts(props)));
    }

    /** Tests pass a builder bound to a mock server. */
    BrevoEmailClient(EmailProperties props, RestClient.Builder builder) {
        this.props = props;
        this.http = builder
                .baseUrl(props.getBaseUrl())
                .defaultHeader(HttpHeaders.ACCEPT, MediaType.APPLICATION_JSON_VALUE)
                .build();
    }

    private static SimpleClientHttpRequestFactory timeouts(EmailProperties props) {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout((int) props.getConnectTimeout().toMillis());
        factory.setReadTimeout((int) props.getReadTimeout().toMillis());
        return factory;
    }

    /** Sends one email and returns Brevo's message id. */
    public String send(EmailMessage message) {
        if (!props.isConfigured()) {
            throw new EmailSendException("Email is not configured (BREVO_API_KEY and EMAIL_SENDER_ADDRESS).", 0);
        }
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("sender", Map.of("name", props.getSenderName(), "email", props.getSenderAddress()));
        body.put("to", List.of(Map.of("email", message.to())));
        body.put("subject", message.subject());
        body.put("htmlContent", message.html());
        body.put("textContent", message.text());
        try {
            Map<?, ?> reply = http.post()
                    .uri("/smtp/email")
                    .header("api-key", props.getApiKey())
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(body)
                    .retrieve()
                    .body(Map.class);
            Object id = reply == null ? null : reply.get("messageId");
            return id == null ? "unknown" : String.valueOf(id);
        } catch (RestClientResponseException e) {
            throw explain(e.getStatusCode().value(), e.getResponseBodyAsString());
        } catch (RestClientException e) {
            throw new EmailSendException("Could not reach Brevo (network problem or timeout).", 0);
        }
    }

    /** Checks the key and the sender without sending anything. Never throws. */
    public EmailHealth check() {
        boolean key = props.hasApiKey();
        boolean sender = props.hasSender();
        if (!key || !sender) {
            String missing = !key && !sender ? "BREVO_API_KEY and EMAIL_SENDER_ADDRESS are not set."
                    : !key ? "BREVO_API_KEY is not set." : "EMAIL_SENDER_ADDRESS is not set.";
            return new EmailHealth("NOT_CONFIGURED", PROVIDER, key, sender, null, null,
                    sender ? props.getSenderAddress() : null, null, missing, Instant.now());
        }
        long started = System.nanoTime();
        try {
            http.get().uri("/account").header("api-key", props.getApiKey()).retrieve().toBodilessEntity();
        } catch (RestClientResponseException e) {
            return down(explain(e.getStatusCode().value(), e.getResponseBodyAsString()).getReason(), started);
        } catch (RestClientException e) {
            return down("Could not reach Brevo (network problem or timeout).", started);
        }
        long latency = (System.nanoTime() - started) / 1_000_000;
        Boolean verified = senderVerified();
        String status;
        String detail;
        if (Boolean.FALSE.equals(verified)) {
            status = "DEGRADED";
            detail = "The API key works, but " + props.getSenderAddress()
                    + " is not an active sender in Brevo. Verify it under Brevo > Senders & IP, or change EMAIL_SENDER_ADDRESS.";
        } else if (verified == null) {
            status = "UP";
            detail = "The API key works. Brevo did not list senders, so the sender could not be checked.";
        } else {
            status = "UP";
            detail = "The API key works and the sender is active.";
        }
        return new EmailHealth(status, PROVIDER, true, true, true, verified, props.getSenderAddress(), latency,
                detail, Instant.now());
    }

    private Boolean senderVerified() {
        try {
            Map<?, ?> reply = http.get().uri("/senders").header("api-key", props.getApiKey())
                    .retrieve().body(Map.class);
            if (reply == null || !(reply.get("senders") instanceof List<?> senders)) {
                return null;
            }
            String wanted = props.getSenderAddress().trim().toLowerCase(Locale.ROOT);
            return senders.stream().anyMatch(s -> s instanceof Map<?, ?> m
                    && wanted.equalsIgnoreCase(String.valueOf(m.get("email")))
                    && !Boolean.FALSE.equals(m.get("active")));
        } catch (RestClientException e) {
            log.debug("Could not list Brevo senders: {}", e.getClass().getSimpleName());
            return null;
        }
    }

    private EmailHealth down(String reason, long startedNanos) {
        return new EmailHealth("DOWN", PROVIDER, true, true, false, null, props.getSenderAddress(),
                (System.nanoTime() - startedNanos) / 1_000_000, reason, Instant.now());
    }

    /** Turns a provider failure into a short sentence an operator can act on. */
    static EmailSendException explain(int status, String body) {
        String text = body == null ? "" : body.toLowerCase(Locale.ROOT);
        String reason;
        if (status == 401 && (text.contains("ip address") || text.contains("unrecognised ip"))) {
            reason = "Brevo blocked this server's IP address. Add it under Brevo > Security > Authorized IPs, "
                    + "or turn the restriction off.";
        } else if (status == 401) {
            reason = "Brevo rejected the API key (check BREVO_API_KEY).";
        } else if (status == 400 && text.contains("sender")) {
            reason = "The sender address is not verified in Brevo (check EMAIL_SENDER_ADDRESS).";
        } else if (status == 402 || status == 403) {
            reason = "Brevo refused the request (HTTP " + status
                    + "): the account may be out of credit, suspended, or the key lacks permission.";
        } else if (status == 429) {
            reason = "Brevo's rate limit was reached. Try again later.";
        } else if (status >= 500) {
            reason = "Brevo had a server error (HTTP " + status + ").";
        } else {
            reason = "Brevo did not accept the request (HTTP " + status + ").";
        }
        return new EmailSendException(reason, status);
    }
}
