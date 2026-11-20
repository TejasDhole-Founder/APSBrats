package com.apsconnect.api.email;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.common.exception.ErrorCode;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.mockito.Mockito;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.http.HttpStatus;
import org.springframework.mock.env.MockEnvironment;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class EmailServiceTest {

    private final BrevoEmailClient brevo = Mockito.mock(BrevoEmailClient.class);
    private final StringRedisTemplate redis = Mockito.mock(StringRedisTemplate.class);
    @SuppressWarnings("unchecked")
    private final ValueOperations<String, String> values = Mockito.mock(ValueOperations.class);
    private final EmailProperties props = new EmailProperties();
    private final MockEnvironment environment = new MockEnvironment();
    private EmailService service;
    private final UUID admin = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        props.setApiKey("secret-test-key");
        props.setSenderAddress("no-reply@apsbrats.com");
        when(redis.opsForValue()).thenReturn(values);
        when(values.increment(anyString())).thenReturn(1L);
        service = new EmailService(brevo, props, redis, environment);
    }

    @Test
    void emailsTheCodeWithItInTheSubjectAndBothBodies() {
        service.sendOtp("person@gmail.com", "123456", 10);

        ArgumentCaptor<EmailMessage> sent = ArgumentCaptor.forClass(EmailMessage.class);
        verify(brevo).send(sent.capture());
        assertThat(sent.getValue().to()).isEqualTo("person@gmail.com");
        assertThat(sent.getValue().subject()).isEqualTo("123456 is your APS Brats code");
        assertThat(sent.getValue().html()).contains("123456").contains("10 minutes");
        assertThat(sent.getValue().text()).contains("123456").contains("10 minutes");
    }

    @Test
    void neverEmailsReservedTestDomains() {
        service.sendOtp("arjun.singh@example.com", "123456", 10);
        service.sendOtp("load5@loadtest.example", "123456", 10);
        service.sendOtp("a@b.test", "123456", 10);

        verify(brevo, never()).send(any());
        assertThat(EmailService.isReservedDomain("person@gmail.com")).isFalse();
        assertThat(EmailService.isReservedDomain("person@notexample.com")).isFalse();
        assertThat(EmailService.isReservedDomain("person@mail.example.org")).isTrue();
    }

    @Test
    void notConfiguredOutsideProdIsSilent() {
        props.setApiKey("");

        service.sendOtp("person@gmail.com", "123456", 10);

        verify(brevo, never()).send(any());
    }

    @Test
    void notConfiguredInProdTellsThePersonInsteadOfFailingSilently() {
        props.setApiKey("");
        environment.setActiveProfiles("prod");

        assertThatThrownBy(() -> service.sendOtp("person@gmail.com", "123456", 10))
                .isInstanceOfSatisfying(AppException.class, e -> {
                    assertThat(e.getStatus()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
                    assertThat(e.getCode()).isEqualTo(ErrorCode.SERVICE_UNAVAILABLE);
                });
    }

    @Test
    void aProviderFailureIsA503WithAGenericMessage() {
        when(brevo.send(any())).thenThrow(new EmailSendException("Brevo rejected the API key (check BREVO_API_KEY).", 401));

        assertThatThrownBy(() -> service.sendOtp("person@gmail.com", "123456", 10))
                .isInstanceOfSatisfying(AppException.class, e -> {
                    assertThat(e.getStatus()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
                    assertThat(e.getMessage()).doesNotContain("Brevo").doesNotContain("API key").doesNotContain("401");
                });
    }

    @Test
    void testEmailReportsSuccessWithAMaskedAddress() {
        when(brevo.send(any())).thenReturn("<id@brevo>");

        EmailService.TestResult result = service.sendTest("person@gmail.com", admin);

        assertThat(result.sent()).isTrue();
        assertThat(result.messageId()).isEqualTo("<id@brevo>");
        assertThat(result.sentTo()).isEqualTo("p***@gmail.com");
        assertThat(result.reason()).isNull();
    }

    @Test
    void testEmailReportsAProviderFailureAsDataNotAnError() {
        when(brevo.send(any())).thenThrow(new EmailSendException("The sender address is not verified in Brevo.", 400));

        EmailService.TestResult result = service.sendTest("person@gmail.com", admin);

        assertThat(result.sent()).isFalse();
        assertThat(result.reason()).contains("sender address");
    }

    @Test
    void testEmailExplainsWhenNotConfiguredAndDoesNotSpendTheLimit() {
        props.setSenderAddress("");

        EmailService.TestResult result = service.sendTest("person@gmail.com", admin);

        assertThat(result.sent()).isFalse();
        assertThat(result.reason()).contains("EMAIL_SENDER_ADDRESS");
        verify(values, never()).increment(anyString());
    }

    @Test
    void testEmailsAreLimitedToFiveAnHourPerAdmin() {
        when(values.increment("ratelimit:email-test:" + admin)).thenReturn(6L);

        assertThatThrownBy(() -> service.sendTest("person@gmail.com", admin))
                .isInstanceOfSatisfying(AppException.class,
                        e -> assertThat(e.getStatus()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS));
        verify(brevo, never()).send(any());
    }

    @Test
    void masksAddresses() {
        assertThat(EmailService.mask("tejas@yardi.com")).isEqualTo("t***@yardi.com");
        assertThat(EmailService.mask("")).isEqualTo("***");
        assertThat(EmailService.mask(null)).isEqualTo("***");
    }
}
