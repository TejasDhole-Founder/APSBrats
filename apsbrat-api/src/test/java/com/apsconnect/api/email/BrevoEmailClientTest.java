package com.apsconnect.api.email;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

import java.io.IOException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.header;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.jsonPath;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.method;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withStatus;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

class BrevoEmailClientTest {

    private static final String BASE = "https://api.brevo.com/v3";
    private static final EmailMessage MESSAGE =
            new EmailMessage("person@gmail.com", "Subject", "<p>Hi</p>", "Hi");

    private EmailProperties props;
    private MockRestServiceServer server;
    private BrevoEmailClient client;

    @BeforeEach
    void setUp() {
        props = new EmailProperties();
        props.setApiKey("secret-test-key");
        props.setSenderAddress("no-reply@apsbrats.com");
        RestClient.Builder builder = RestClient.builder();
        server = MockRestServiceServer.bindTo(builder).build();
        client = new BrevoEmailClient(props, builder);
    }

    @Test
    void sendsOneEmailWithTheKeySenderRecipientAndBothBodies() {
        server.expect(requestTo(BASE + "/smtp/email"))
                .andExpect(method(HttpMethod.POST))
                .andExpect(header("api-key", "secret-test-key"))
                .andExpect(jsonPath("$.sender.email").value("no-reply@apsbrats.com"))
                .andExpect(jsonPath("$.sender.name").value("APS Brats"))
                .andExpect(jsonPath("$.to[0].email").value("person@gmail.com"))
                .andExpect(jsonPath("$.subject").value("Subject"))
                .andExpect(jsonPath("$.htmlContent").value("<p>Hi</p>"))
                .andExpect(jsonPath("$.textContent").value("Hi"))
                .andRespond(withStatus(org.springframework.http.HttpStatus.CREATED)
                        .contentType(MediaType.APPLICATION_JSON).body("{\"messageId\":\"<abc@brevo>\"}"));

        assertThat(client.send(MESSAGE)).isEqualTo("<abc@brevo>");
        server.verify();
    }

    @Test
    void explainsARejectedKey() {
        server.expect(requestTo(BASE + "/smtp/email")).andRespond(withStatus(org.springframework.http.HttpStatus.UNAUTHORIZED)
                .contentType(MediaType.APPLICATION_JSON).body("{\"message\":\"Key not found\",\"code\":\"unauthorized\"}"));

        assertThatThrownBy(() -> client.send(MESSAGE))
                .isInstanceOfSatisfying(EmailSendException.class, e -> {
                    assertThat(e.getProviderStatus()).isEqualTo(401);
                    assertThat(e.getReason()).contains("API key");
                    assertThat(e.getReason()).doesNotContain("secret-test-key");
                });
    }

    @Test
    void explainsABlockedIpAddress() {
        server.expect(requestTo(BASE + "/smtp/email")).andRespond(withStatus(org.springframework.http.HttpStatus.UNAUTHORIZED)
                .contentType(MediaType.APPLICATION_JSON)
                .body("{\"message\":\"We have detected you are using an unrecognised IP address 1.2.3.4\"}"));

        assertThatThrownBy(() -> client.send(MESSAGE))
                .isInstanceOfSatisfying(EmailSendException.class,
                        e -> assertThat(e.getReason()).contains("IP address").contains("Authorized IPs"));
    }

    @Test
    void explainsAnUnverifiedSender() {
        server.expect(requestTo(BASE + "/smtp/email")).andRespond(withStatus(org.springframework.http.HttpStatus.BAD_REQUEST)
                .contentType(MediaType.APPLICATION_JSON).body("{\"message\":\"Sender is not valid\"}"));

        assertThatThrownBy(() -> client.send(MESSAGE))
                .isInstanceOfSatisfying(EmailSendException.class,
                        e -> assertThat(e.getReason()).contains("EMAIL_SENDER_ADDRESS"));
    }

    @Test
    void explainsAProviderOutage() {
        server.expect(requestTo(BASE + "/smtp/email"))
                .andRespond(withStatus(org.springframework.http.HttpStatus.BAD_GATEWAY));

        assertThatThrownBy(() -> client.send(MESSAGE))
                .isInstanceOfSatisfying(EmailSendException.class, e -> {
                    assertThat(e.getProviderStatus()).isEqualTo(502);
                    assertThat(e.getReason()).contains("server error");
                });
    }

    @Test
    void anUnreachableProviderIsReportedWithoutAStatus() {
        server.expect(requestTo(BASE + "/smtp/email")).andRespond(request -> {
            throw new IOException("connection refused");
        });

        assertThatThrownBy(() -> client.send(MESSAGE))
                .isInstanceOfSatisfying(EmailSendException.class, e -> {
                    assertThat(e.getProviderStatus()).isZero();
                    assertThat(e.getReason()).contains("Could not reach Brevo");
                });
    }

    @Test
    void refusesToSendWhenNotConfigured() {
        props.setApiKey("");

        assertThatThrownBy(() -> client.send(MESSAGE)).isInstanceOf(EmailSendException.class);
        server.verify();
    }

    @Test
    void healthIsNotConfiguredWithoutCallingBrevo() {
        props.setApiKey("");
        props.setSenderAddress("");

        EmailHealth health = client.check();

        assertThat(health.status()).isEqualTo("NOT_CONFIGURED");
        assertThat(health.apiKeySet()).isFalse();
        assertThat(health.senderSet()).isFalse();
        assertThat(health.detail()).contains("BREVO_API_KEY").contains("EMAIL_SENDER_ADDRESS");
        server.verify();
    }

    @Test
    void healthIsUpWhenTheKeyWorksAndTheSenderIsActive() {
        server.expect(requestTo(BASE + "/account")).andExpect(header("api-key", "secret-test-key"))
                .andRespond(withSuccess("{}", MediaType.APPLICATION_JSON));
        server.expect(requestTo(BASE + "/senders")).andRespond(withSuccess(
                "{\"senders\":[{\"id\":1,\"email\":\"No-Reply@apsbrats.com\",\"active\":true}]}",
                MediaType.APPLICATION_JSON));

        EmailHealth health = client.check();

        assertThat(health.status()).isEqualTo("UP");
        assertThat(health.apiKeyValid()).isTrue();
        assertThat(health.senderVerified()).isTrue();
        assertThat(health.latencyMs()).isNotNull();
        assertThat(health.toString()).doesNotContain("secret-test-key");
        server.verify();
    }

    @Test
    void healthIsDegradedWhenTheSenderIsNotListed() {
        server.expect(requestTo(BASE + "/account")).andRespond(withSuccess("{}", MediaType.APPLICATION_JSON));
        server.expect(requestTo(BASE + "/senders")).andRespond(withSuccess(
                "{\"senders\":[{\"id\":2,\"email\":\"someone@else.com\",\"active\":true}]}", MediaType.APPLICATION_JSON));

        EmailHealth health = client.check();

        assertThat(health.status()).isEqualTo("DEGRADED");
        assertThat(health.senderVerified()).isFalse();
        assertThat(health.detail()).contains("no-reply@apsbrats.com");
    }

    @Test
    void healthIsDownWhenTheKeyIsRejected() {
        server.expect(requestTo(BASE + "/account")).andRespond(withStatus(org.springframework.http.HttpStatus.UNAUTHORIZED)
                .contentType(MediaType.APPLICATION_JSON).body("{\"message\":\"Key not found\"}"));

        EmailHealth health = client.check();

        assertThat(health.status()).isEqualTo("DOWN");
        assertThat(health.apiKeyValid()).isFalse();
        assertThat(health.detail()).contains("API key");
    }

    @Test
    void healthStaysUpWhenSendersCannotBeListed() {
        server.expect(requestTo(BASE + "/account")).andRespond(withSuccess("{}", MediaType.APPLICATION_JSON));
        server.expect(requestTo(BASE + "/senders"))
                .andRespond(withStatus(org.springframework.http.HttpStatus.FORBIDDEN));

        EmailHealth health = client.check();

        assertThat(health.status()).isEqualTo("UP");
        assertThat(health.senderVerified()).isNull();
    }
}
