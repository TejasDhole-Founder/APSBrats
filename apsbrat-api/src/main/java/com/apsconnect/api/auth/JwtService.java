package com.apsconnect.api.auth;

import com.apsconnect.api.common.exception.AppException;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Date;
import java.util.UUID;

@Service
public class JwtService {

    private static final Logger log = LoggerFactory.getLogger(JwtService.class);
    private static final int MIN_SECRET_LENGTH = 32;

    private final SecretKey key;
    private final long accessTokenExpiry;
    private final long refreshTokenExpiry;

    public JwtService(
            @Value("${app.jwt.secret}") String secret,
            @Value("${app.jwt.access-token-expiry}") long accessTokenExpiry,
            @Value("${app.jwt.refresh-token-expiry}") long refreshTokenExpiry,
            Environment environment) {
        validateSecret(secret, environment);
        this.key = deriveKey(secret);
        this.accessTokenExpiry = accessTokenExpiry;
        this.refreshTokenExpiry = refreshTokenExpiry;
    }

    public String generateAccessToken(UUID userId, String phone, String role) {
        return build(userId, accessTokenExpiry, "access", phone, null, role);
    }

    public String generateRefreshToken(UUID userId, String jti) {
        return build(userId, refreshTokenExpiry, "refresh", null, jti, null);
    }

    public String parseJti(String token) {
        return parse(token).getId();
    }

    public String parseRole(String token) {
        return parse(token).get("role", String.class);
    }

    public long getRefreshTokenExpiryMillis() {
        return refreshTokenExpiry;
    }

    public UUID parseUserId(String token) {
        Claims claims = parse(token);
        return UUID.fromString(claims.getSubject());
    }

    public boolean isRefreshToken(String token) {
        return "refresh".equals(parse(token).get("type", String.class));
    }

    private String build(UUID userId, long ttlMillis, String type, String phone, String jti, String role) {
        Date now = new Date();
        var builder = Jwts.builder()
                .subject(userId.toString())
                .claim("type", type)
                .issuedAt(now)
                .expiration(new Date(now.getTime() + ttlMillis))
                .signWith(key);
        if (phone != null) {
            builder.claim("phone", phone);
        }
        if (role != null) {
            builder.claim("role", role);
        }
        if (jti != null) {
            builder.id(jti);
        }
        return builder.compact();
    }

    private static void validateSecret(String secret, Environment env) {
        boolean weak = secret == null || secret.isBlank()
                || secret.contains("change-me")
                || secret.length() < MIN_SECRET_LENGTH;
        if (!weak) {
            return;
        }
        if (env.acceptsProfiles(Profiles.of("prod", "qa"))) {
            throw new IllegalStateException(
                    "JWT_SECRET must be a random secret of at least " + MIN_SECRET_LENGTH
                            + " characters in qa/prod profiles");
        }
        log.warn("Weak JWT secret in use — acceptable for dev only");
    }

    private Claims parse(String token) {
        try {
            return Jwts.parser().verifyWith(key).build().parseSignedClaims(token).getPayload();
        } catch (Exception ex) {
            throw new AppException("Invalid or expired token", HttpStatus.UNAUTHORIZED);
        }
    }

    private static SecretKey deriveKey(String secret) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(secret.getBytes(StandardCharsets.UTF_8));
            return Keys.hmacShaKeyFor(digest);
        } catch (NoSuchAlgorithmException ex) {
            throw new IllegalStateException("SHA-256 not available", ex);
        }
    }
}
