package com.apsconnect.api.auth;

import com.apsconnect.api.common.exception.AppException;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
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

    private final SecretKey key;
    private final long accessTokenExpiry;
    private final long refreshTokenExpiry;

    public JwtService(
            @Value("${app.jwt.secret}") String secret,
            @Value("${app.jwt.access-token-expiry}") long accessTokenExpiry,
            @Value("${app.jwt.refresh-token-expiry}") long refreshTokenExpiry) {
        this.key = deriveKey(secret);
        this.accessTokenExpiry = accessTokenExpiry;
        this.refreshTokenExpiry = refreshTokenExpiry;
    }

    public String generateAccessToken(UUID userId, String phone) {
        return build(userId, refreshTokenExpiryFor(false), "access", phone);
    }

    public String generateRefreshToken(UUID userId) {
        return build(userId, refreshTokenExpiryFor(true), "refresh", null);
    }

    public UUID parseUserId(String token) {
        Claims claims = parse(token);
        return UUID.fromString(claims.getSubject());
    }

    public boolean isRefreshToken(String token) {
        return "refresh".equals(parse(token).get("type", String.class));
    }

    private long refreshTokenExpiryFor(boolean refresh) {
        return refresh ? refreshTokenExpiry : accessTokenExpiry;
    }

    private String build(UUID userId, long ttlMillis, String type, String phone) {
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
        return builder.compact();
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
