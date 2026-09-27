package com.apsconnect.api.auth;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.common.exception.ErrorCode;
import com.apsconnect.api.user.User;
import com.apsconnect.api.user.UserDto;
import com.apsconnect.api.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Email + OTP, or Google via Firebase — both resolve to an email and both are
 * "log in if we know you, otherwise create the bare account and let onboarding
 * fill it in". There is no separate registration endpoint any more.
 */
@Service
@RequiredArgsConstructor
public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);
    private static final SecureRandom RANDOM = new SecureRandom();
    private static final int OTP_TTL_MINUTES = 10;
    private static final Duration RESEND_COOLDOWN = Duration.ofSeconds(60);
    private static final Duration REQUEST_WINDOW = Duration.ofHours(1);
    private static final int MAX_REQUESTS_PER_EMAIL = 5;
    private static final int MAX_REQUESTS_PER_IP = 15;
    private static final int MAX_VERIFY_ATTEMPTS = 5;
    private static final Duration ATTEMPT_WINDOW = Duration.ofMinutes(15);
    private static final Duration LOCKOUT = Duration.ofMinutes(15);

    private final OtpCodeRepository otpCodeRepository;
    private final UserRepository userRepository;
    private final JwtService jwtService;
    private final StringRedisTemplate redis;
    private final Environment environment;
    private final FirebaseAuthVerifier googleVerifier;

    @Value("${app.otp.master:}")
    private String masterOtp;

    @Transactional
    public void requestOtp(String rawEmail, String clientIp) {
        String email = normalize(rawEmail);
        enforceRequestLimits(email, clientIp);

        String code = String.format("%06d", RANDOM.nextInt(1_000_000));

        OtpCode otp = new OtpCode();
        otp.setEmail(email);
        otp.setCode(code);
        otp.setExpiresAt(LocalDateTime.now().plusMinutes(OTP_TTL_MINUTES));
        otp.setConsumed(false);
        otpCodeRepository.save(otp);

        if (!isProd()) {
            log.info("OTP for {} is {}", email, code);
        }
        // TODO: send the code by email in qa/prod (an EmailSender interface, the
        // same shape as this OTP flow already has for rate limiting) — for now
        // it only ever reaches the console/log, same as phone OTP did before.
    }

    @Transactional
    public AuthTokens verifyOtp(String rawEmail, String code) {
        String email = normalize(rawEmail);

        if (Boolean.TRUE.equals(redis.hasKey(lockKey(email)))) {
            throw new AppException("Too many attempts. Try again later.",
                    HttpStatus.TOO_MANY_REQUESTS, ErrorCode.RATE_LIMITED);
        }

        if (!masterOtpMatches(code)) {
            OtpCode otp = otpCodeRepository.findTopByEmailAndConsumedFalseOrderByCreatedAtDesc(email)
                    .orElseThrow(() -> new AppException("No OTP requested for this email", HttpStatus.BAD_REQUEST));
            if (otp.getExpiresAt().isBefore(LocalDateTime.now())) {
                throw new AppException("OTP expired", HttpStatus.BAD_REQUEST);
            }
            if (!constantTimeEquals(otp.getCode(), code)) {
                registerFailedAttempt(email);
                throw new AppException("Incorrect OTP", HttpStatus.BAD_REQUEST);
            }
            otp.setConsumed(true);
            otpCodeRepository.save(otp);
        }
        redis.delete(attemptKey(email));

        User user = findOrCreateByEmail(email, null, null);
        ensureNotBannedOrSuspended(user);
        user.setIsVerified(Boolean.TRUE);
        userRepository.save(user);

        return issueTokens(user);
    }

    /** Google sign-in: Firebase already proved the email, so there is no OTP step at all. */
    @Transactional
    public AuthTokens signInWithGoogle(String idToken) {
        FirebaseAuthVerifier.GoogleIdentity identity = googleVerifier.verify(idToken);
        User user = findOrCreateByEmail(identity.email(), identity.name(), identity.pictureUrl());
        ensureNotBannedOrSuspended(user);
        user.setIsVerified(Boolean.TRUE);
        userRepository.save(user);
        return issueTokens(user);
    }

    /** Existing account with this email, or a bare one for onboarding to fill in. */
    private User findOrCreateByEmail(String email, String nameIfNew, String pictureIfNew) {
        return userRepository.findByEmail(email).orElseGet(() -> {
            User user = new User();
            user.setEmail(email);
            user.setFullName(nameIfNew);
            user.setProfilePicUrl(pictureIfNew);
            return userRepository.save(user);
        });
    }

    private void ensureNotBannedOrSuspended(User user) {
        if (user.isBanned()) {
            throw new AppException("This account has been permanently suspended.",
                    HttpStatus.FORBIDDEN, ErrorCode.FORBIDDEN);
        }
        if (user.isSuspended()) {
            throw new AppException("This account is temporarily suspended.",
                    HttpStatus.FORBIDDEN, ErrorCode.FORBIDDEN);
        }
    }

    @Transactional(readOnly = true)
    public AuthTokens refresh(String refreshToken) {
        if (!jwtService.isRefreshToken(refreshToken)) {
            throw new AppException("Not a refresh token", HttpStatus.BAD_REQUEST);
        }
        String jti = jwtService.parseJti(refreshToken);
        if (jti == null || !Boolean.TRUE.equals(redis.delete(refreshKey(jti)))) {
            throw new AppException("Invalid or expired token", HttpStatus.UNAUTHORIZED, ErrorCode.UNAUTHORIZED);
        }
        var userId = jwtService.parseUserId(refreshToken);
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new AppException("User not found", HttpStatus.NOT_FOUND));
        ensureNotBannedOrSuspended(user);
        return issueTokens(user);
    }

    public void logout(String refreshToken) {
        if (!jwtService.isRefreshToken(refreshToken)) {
            throw new AppException("Not a refresh token", HttpStatus.BAD_REQUEST);
        }
        String jti = jwtService.parseJti(refreshToken);
        if (jti != null) {
            redis.delete(refreshKey(jti));
            redis.opsForSet().remove(userTokensKey(jwtService.parseUserId(refreshToken).toString()), jti);
        }
    }

    public void revokeAllFor(UUID userId) {
        String setKey = userTokensKey(userId.toString());
        var jtis = redis.opsForSet().members(setKey);
        if (jtis != null) {
            for (String jti : jtis) {
                redis.delete(refreshKey(jti));
            }
        }
        redis.delete(setKey);
    }

    private AuthTokens issueTokens(User user) {
        String jti = UUID.randomUUID().toString();
        String roleName = user.getRole() == null ? "USER" : user.getRole().name();
        String access = jwtService.generateAccessToken(user.getId(), user.getEmail(), roleName);
        String refresh = jwtService.generateRefreshToken(user.getId(), jti);
        Duration ttl = Duration.ofMillis(jwtService.getRefreshTokenExpiryMillis());
        redis.opsForValue().set(refreshKey(jti), user.getId().toString(), ttl);
        String setKey = userTokensKey(user.getId().toString());
        redis.opsForSet().add(setKey, jti);
        redis.expire(setKey, ttl);
        return new AuthTokens(access, refresh, UserDto.from(user));
    }

    private void enforceRequestLimits(String email, String clientIp) {
        if (Boolean.TRUE.equals(redis.hasKey(cooldownKey(email)))) {
            throw new AppException("Please wait before requesting another OTP",
                    HttpStatus.TOO_MANY_REQUESTS, ErrorCode.RATE_LIMITED);
        }
        if (incrementWindow(requestKey(email), REQUEST_WINDOW) > MAX_REQUESTS_PER_EMAIL
                || incrementWindow(ipKey(clientIp), REQUEST_WINDOW) > MAX_REQUESTS_PER_IP) {
            throw new AppException("Too many OTP requests. Try again later.",
                    HttpStatus.TOO_MANY_REQUESTS, ErrorCode.RATE_LIMITED);
        }
        redis.opsForValue().set(cooldownKey(email), "1", RESEND_COOLDOWN);
    }

    private void registerFailedAttempt(String email) {
        long attempts = incrementWindow(attemptKey(email), ATTEMPT_WINDOW);
        if (attempts >= MAX_VERIFY_ATTEMPTS) {
            redis.opsForValue().set(lockKey(email), "1", LOCKOUT);
            redis.delete(attemptKey(email));
        }
    }

    private long incrementWindow(String key, Duration window) {
        Long count = redis.opsForValue().increment(key);
        if (count != null && count == 1L) {
            redis.expire(key, window);
        }
        return count == null ? 0 : count;
    }

    private boolean masterOtpMatches(String code) {
        return !isProd()
                && masterOtp != null && !masterOtp.isBlank()
                && constantTimeEquals(masterOtp, code);
    }

    private boolean isProd() {
        return environment.acceptsProfiles(Profiles.of("prod"));
    }

    private static boolean constantTimeEquals(String expected, String given) {
        if (expected == null || given == null) {
            return false;
        }
        return MessageDigest.isEqual(
                expected.getBytes(StandardCharsets.UTF_8),
                given.getBytes(StandardCharsets.UTF_8));
    }

    private static String cooldownKey(String email) { return "otp:cd:" + email; }
    private static String requestKey(String email) { return "otp:rq:" + email; }
    private static String ipKey(String ip) { return "otp:ip:" + ip; }
    private static String attemptKey(String email) { return "otp:att:" + email; }
    private static String lockKey(String email) { return "otp:lock:" + email; }
    private static String refreshKey(String jti) { return "rt:" + jti; }
    private static String userTokensKey(String userId) { return "rtu:" + userId; }

    private String normalize(String email) {
        return email == null ? "" : email.trim().toLowerCase();
    }
}
