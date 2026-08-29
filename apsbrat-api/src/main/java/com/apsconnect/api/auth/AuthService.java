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

@Service
@RequiredArgsConstructor
public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);
    private static final SecureRandom RANDOM = new SecureRandom();
    private static final int OTP_TTL_MINUTES = 10;
    private static final Duration RESEND_COOLDOWN = Duration.ofSeconds(60);
    private static final Duration REQUEST_WINDOW = Duration.ofHours(1);
    private static final int MAX_REQUESTS_PER_PHONE = 5;
    private static final int MAX_REQUESTS_PER_IP = 15;
    private static final int MAX_VERIFY_ATTEMPTS = 5;
    private static final Duration ATTEMPT_WINDOW = Duration.ofMinutes(15);
    private static final Duration LOCKOUT = Duration.ofMinutes(15);

    private final OtpCodeRepository otpCodeRepository;
    private final UserRepository userRepository;
    private final JwtService jwtService;
    private final StringRedisTemplate redis;
    private final Environment environment;

    @Value("${app.otp.master:}")
    private String masterOtp;

    @Transactional
    public void requestOtp(String rawPhone, String clientIp) {
        String phone = normalize(rawPhone);
        enforceRequestLimits(phone, clientIp);

        String code = String.format("%06d", RANDOM.nextInt(1_000_000));

        OtpCode otp = new OtpCode();
        otp.setPhone(phone);
        otp.setCode(code);
        otp.setExpiresAt(LocalDateTime.now().plusMinutes(OTP_TTL_MINUTES));
        otp.setConsumed(false);
        otpCodeRepository.save(otp);

        if (!isProd()) {
            log.info("OTP for {} is {}", phone, code);
        }
    }

    @Transactional
    public AuthTokens verifyOtp(String rawPhone, String code) {
        String phone = normalize(rawPhone);

        if (Boolean.TRUE.equals(redis.hasKey(lockKey(phone)))) {
            throw new AppException("Too many attempts. Try again later.",
                    HttpStatus.TOO_MANY_REQUESTS, ErrorCode.RATE_LIMITED);
        }

        if (!masterOtpMatches(code)) {
            OtpCode otp = otpCodeRepository.findTopByPhoneAndConsumedFalseOrderByCreatedAtDesc(phone)
                    .orElseThrow(() -> new AppException("No OTP requested for this phone", HttpStatus.BAD_REQUEST));
            if (otp.getExpiresAt().isBefore(LocalDateTime.now())) {
                throw new AppException("OTP expired", HttpStatus.BAD_REQUEST);
            }
            if (!constantTimeEquals(otp.getCode(), code)) {
                registerFailedAttempt(phone);
                throw new AppException("Incorrect OTP", HttpStatus.BAD_REQUEST);
            }
            otp.setConsumed(true);
            otpCodeRepository.save(otp);
        }
        redis.delete(attemptKey(phone));

        User user = userRepository.findByPhone(phone)
                .orElseThrow(() -> new AppException("No account for this phone. Please register first.", HttpStatus.NOT_FOUND));
        ensureNotBannedOrSuspended(user);
        user.setIsVerified(Boolean.TRUE);
        userRepository.save(user);

        return issueTokens(user);
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
        String access = jwtService.generateAccessToken(user.getId(), user.getPhone(), roleName);
        String refresh = jwtService.generateRefreshToken(user.getId(), jti);
        Duration ttl = Duration.ofMillis(jwtService.getRefreshTokenExpiryMillis());
        redis.opsForValue().set(refreshKey(jti), user.getId().toString(), ttl);
        String setKey = userTokensKey(user.getId().toString());
        redis.opsForSet().add(setKey, jti);
        redis.expire(setKey, ttl);
        return new AuthTokens(access, refresh, UserDto.from(user));
    }

    private void enforceRequestLimits(String phone, String clientIp) {
        if (Boolean.TRUE.equals(redis.hasKey(cooldownKey(phone)))) {
            throw new AppException("Please wait before requesting another OTP",
                    HttpStatus.TOO_MANY_REQUESTS, ErrorCode.RATE_LIMITED);
        }
        if (incrementWindow(requestKey(phone), REQUEST_WINDOW) > MAX_REQUESTS_PER_PHONE
                || incrementWindow(ipKey(clientIp), REQUEST_WINDOW) > MAX_REQUESTS_PER_IP) {
            throw new AppException("Too many OTP requests. Try again later.",
                    HttpStatus.TOO_MANY_REQUESTS, ErrorCode.RATE_LIMITED);
        }
        redis.opsForValue().set(cooldownKey(phone), "1", RESEND_COOLDOWN);
    }

    private void registerFailedAttempt(String phone) {
        long attempts = incrementWindow(attemptKey(phone), ATTEMPT_WINDOW);
        if (attempts >= MAX_VERIFY_ATTEMPTS) {
            redis.opsForValue().set(lockKey(phone), "1", LOCKOUT);
            redis.delete(attemptKey(phone));
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

    private static String cooldownKey(String phone) { return "otp:cd:" + phone; }
    private static String requestKey(String phone) { return "otp:rq:" + phone; }
    private static String ipKey(String ip) { return "otp:ip:" + ip; }
    private static String attemptKey(String phone) { return "otp:att:" + phone; }
    private static String lockKey(String phone) { return "otp:lock:" + phone; }
    private static String refreshKey(String jti) { return "rt:" + jti; }
    private static String userTokensKey(String userId) { return "rtu:" + userId; }

    private String normalize(String phone) {
        return phone == null ? "" : phone.trim();
    }
}
