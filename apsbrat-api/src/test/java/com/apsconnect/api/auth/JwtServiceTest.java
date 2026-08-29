package com.apsconnect.api.auth;

import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JwtServiceTest {

    private static final String STRONG_SECRET = "a-sufficiently-long-random-secret-value-123456";

    private JwtService service(String secret, String profile) {
        MockEnvironment env = new MockEnvironment();
        env.setActiveProfiles(profile);
        return new JwtService(secret, 900000, 2592000000L, env);
    }

    @Test
    void defaultSecretFailsStartupInProd() {
        assertThatThrownBy(() -> service("change-me", "prod"))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void shortSecretFailsStartupInQa() {
        assertThatThrownBy(() -> service("short", "qa"))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void weakSecretAllowedInDev() {
        assertThat(service("change-me", "dev")).isNotNull();
    }

    @Test
    void refreshTokenCarriesJtiAndType() {
        JwtService jwt = service(STRONG_SECRET, "dev");
        UUID userId = UUID.randomUUID();
        String jti = UUID.randomUUID().toString();

        String token = jwt.generateRefreshToken(userId, jti);

        assertThat(jwt.isRefreshToken(token)).isTrue();
        assertThat(jwt.parseJti(token)).isEqualTo(jti);
        assertThat(jwt.parseUserId(token)).isEqualTo(userId);
    }

    @Test
    void accessTokenIsNotRefreshToken() {
        JwtService jwt = service(STRONG_SECRET, "dev");
        String token = jwt.generateAccessToken(UUID.randomUUID(), "+911234567890", "USER");
        assertThat(jwt.isRefreshToken(token)).isFalse();
        assertThat(jwt.parseRole(token)).isEqualTo("USER");
    }
}
