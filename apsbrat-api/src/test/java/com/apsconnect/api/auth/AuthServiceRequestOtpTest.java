package com.apsconnect.api.auth;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.email.EmailService;
import com.apsconnect.api.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.mockito.Mockito;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.http.HttpStatus;
import org.springframework.mock.env.MockEnvironment;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AuthServiceRequestOtpTest {

    private final OtpCodeRepository otpCodes = Mockito.mock(OtpCodeRepository.class);
    private final StringRedisTemplate redis = Mockito.mock(StringRedisTemplate.class);
    @SuppressWarnings("unchecked")
    private final ValueOperations<String, String> values = Mockito.mock(ValueOperations.class);
    private final EmailService email = Mockito.mock(EmailService.class);
    private AuthService service;

    @BeforeEach
    void setUp() {
        when(redis.opsForValue()).thenReturn(values);
        when(values.increment(anyString())).thenReturn(1L);
        service = new AuthService(otpCodes, Mockito.mock(UserRepository.class), Mockito.mock(JwtService.class),
                redis, new MockEnvironment(), Mockito.mock(FirebaseAuthVerifier.class), email);
    }

    @Test
    void savesTheCodeAndEmailsItToTheNormalisedAddress() {
        service.requestOtp("  Person@Gmail.com ", "1.2.3.4");

        ArgumentCaptor<OtpCode> saved = ArgumentCaptor.forClass(OtpCode.class);
        verify(otpCodes).save(saved.capture());
        assertThat(saved.getValue().getEmail()).isEqualTo("person@gmail.com");
        ArgumentCaptor<String> sentCode = ArgumentCaptor.forClass(String.class);
        verify(email).sendOtp(eq("person@gmail.com"), sentCode.capture(), eq(10));
        assertThat(sentCode.getValue()).matches("\\d{6}").isEqualTo(saved.getValue().getCode());
    }

    @Test
    void aFailedSendDiscardsTheCodeAndFreesTheResendCooldown() {
        doThrow(new AppException("We couldn't send your code.", HttpStatus.SERVICE_UNAVAILABLE))
                .when(email).sendOtp(anyString(), anyString(), anyInt());

        assertThatThrownBy(() -> service.requestOtp("person@gmail.com", "1.2.3.4"))
                .isInstanceOf(AppException.class);

        verify(otpCodes).delete(Mockito.any(OtpCode.class));
        verify(redis).delete("otp:cd:person@gmail.com");
    }

    @Test
    void aRateLimitedRequestNeverReachesTheEmailProvider() {
        when(redis.hasKey("otp:cd:person@gmail.com")).thenReturn(true);

        assertThatThrownBy(() -> service.requestOtp("person@gmail.com", "1.2.3.4"))
                .isInstanceOf(AppException.class);

        verify(email, never()).sendOtp(anyString(), anyString(), anyInt());
        verify(otpCodes, never()).save(Mockito.any());
    }
}
