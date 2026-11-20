package com.apsconnect.api.email;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.common.exception.ErrorCode;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;

/**
 * Decides whether and what to send; {@link BrevoEmailClient} does the sending.
 * Sign-in codes go through here, and so do the admin test email and health check.
 */
@Service
@RequiredArgsConstructor
public class EmailService {

    private static final Logger log = LoggerFactory.getLogger(EmailService.class);
    static final int TEST_EMAILS_PER_HOUR = 5;
    /** RFC 2606 / 6761 names that can never receive mail: sending would only create bounces. */
    private static final Set<String> RESERVED_HOSTS = Set.of("example.com", "example.net", "example.org");
    private static final List<String> RESERVED_SUFFIXES =
            List.of(".test", ".example", ".invalid", ".localhost", ".local");

    /** The result of an admin test email: the call worked either way, this says what happened. */
    public record TestResult(boolean sent, String provider, String sentTo, String messageId, String reason) {
    }

    private final BrevoEmailClient brevo;
    private final EmailProperties props;
    private final StringRedisTemplate redis;
    private final Environment environment;

    /**
     * Emails a sign-in code. Silent for reserved test domains (demo and load-test
     * accounts) and, outside prod, when email is not configured (the code is in
     * the log there). In prod a missing configuration or a provider failure is a
     * 503, so the person is told instead of waiting for a code that never comes.
     */
    public void sendOtp(String to, String code, int ttlMinutes) {
        if (isReservedDomain(to)) {
            log.debug("Skipping the sign-in email: reserved test domain");
            return;
        }
        if (!props.isConfigured()) {
            if (isProd()) {
                log.error("Sign-in codes cannot be emailed: BREVO_API_KEY and EMAIL_SENDER_ADDRESS are not set");
                throw unavailable();
            }
            log.debug("Email is not configured; not sending (the code is in the log outside prod)");
            return;
        }
        try {
            brevo.send(otpMessage(to, code, ttlMinutes));
        } catch (EmailSendException e) {
            log.warn("Sign-in email was not sent: {} (HTTP {})", e.getReason(), e.getProviderStatus());
            throw unavailable();
        }
    }

    /** Sends a test email for an admin and says what happened. At most 5 an hour per admin. */
    public TestResult sendTest(String to, UUID adminId) {
        if (!props.isConfigured()) {
            return new TestResult(false, "brevo", mask(to), null,
                    "Email is not configured: set BREVO_API_KEY and EMAIL_SENDER_ADDRESS.");
        }
        rateLimitTests(adminId);
        try {
            String id = brevo.send(testMessage(to));
            return new TestResult(true, "brevo", mask(to), id, null);
        } catch (EmailSendException e) {
            log.warn("Test email was not sent: {} (HTTP {})", e.getReason(), e.getProviderStatus());
            return new TestResult(false, "brevo", mask(to), null, e.getReason());
        }
    }

    public EmailHealth health() {
        return brevo.check();
    }

    private void rateLimitTests(UUID adminId) {
        String key = "ratelimit:email-test:" + adminId;
        Long count = redis.opsForValue().increment(key);
        if (count != null && count == 1L) {
            redis.expire(key, Duration.ofHours(1));
        }
        if (count != null && count > TEST_EMAILS_PER_HOUR) {
            throw new AppException("Too many test emails. Try again in a while.",
                    HttpStatus.TOO_MANY_REQUESTS, ErrorCode.RATE_LIMITED);
        }
    }

    private AppException unavailable() {
        return new AppException("We couldn't send your code. Please try again in a moment.",
                HttpStatus.SERVICE_UNAVAILABLE, ErrorCode.SERVICE_UNAVAILABLE);
    }

    private boolean isProd() {
        return environment.acceptsProfiles(Profiles.of("prod"));
    }

    static boolean isReservedDomain(String email) {
        if (email == null) {
            return false;
        }
        int at = email.lastIndexOf('@');
        if (at < 0) {
            return false;
        }
        String domain = email.substring(at + 1).trim().toLowerCase(Locale.ROOT);
        return RESERVED_HOSTS.stream().anyMatch(h -> domain.equals(h) || domain.endsWith("." + h))
                || RESERVED_SUFFIXES.stream().anyMatch(domain::endsWith);
    }

    /** t***@example.com: enough to recognise your own address, not enough to harvest one. */
    static String mask(String email) {
        int at = email == null ? -1 : email.indexOf('@');
        return at < 1 ? "***" : email.charAt(0) + "***" + email.substring(at);
    }

    static EmailMessage otpMessage(String to, String code, int ttlMinutes) {
        String html = """
                <div style="font-family:Arial,Helvetica,sans-serif;max-width:480px;margin:0 auto;padding:24px;color:#2a1a14">
                  <h2 style="color:#7b1414;margin:0 0 12px">APS Brats</h2>
                  <p style="margin:0 0 16px">Use this code to sign in:</p>
                  <p style="font-size:32px;letter-spacing:8px;font-weight:700;margin:0 0 16px;color:#7b1414">%s</p>
                  <p style="margin:0 0 8px;color:#555">It expires in %d minutes. Never share it with anyone.</p>
                  <p style="margin:0;color:#888;font-size:12px">If you didn't ask for this code, you can ignore this email.</p>
                </div>
                """.formatted(code, ttlMinutes);
        String text = "Your APS Brats sign-in code is " + code + ".\n"
                + "It expires in " + ttlMinutes + " minutes. Never share it with anyone.\n"
                + "If you didn't ask for this code, you can ignore this email.\n";
        return new EmailMessage(to, code + " is your APS Brats code", html, text);
    }

    private EmailMessage testMessage(String to) {
        String env = String.join(",", environment.getActiveProfiles());
        String when = Instant.now().toString();
        String html = """
                <div style="font-family:Arial,Helvetica,sans-serif;max-width:480px;margin:0 auto;padding:24px;color:#2a1a14">
                  <h2 style="color:#7b1414;margin:0 0 12px">APS Brats email test</h2>
                  <p style="margin:0 0 8px">Email delivery from the API is working.</p>
                  <p style="margin:0;color:#888;font-size:12px">Environment: %s. Sent at %s.</p>
                </div>
                """.formatted(env.isBlank() ? "default" : env, when);
        String text = "APS Brats email test: email delivery from the API is working.\n"
                + "Environment: " + (env.isBlank() ? "default" : env) + ". Sent at " + when + ".\n";
        return new EmailMessage(to, "APS Brats email test", html, text);
    }
}
