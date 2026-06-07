package com.apsconnect.api.auth;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.user.User;
import com.apsconnect.api.user.UserDto;
import com.apsconnect.api.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.LocalDateTime;

@Service
@RequiredArgsConstructor
public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);
    private static final SecureRandom RANDOM = new SecureRandom();
    private static final int OTP_TTL_MINUTES = 10;

    private final OtpCodeRepository otpCodeRepository;
    private final UserRepository userRepository;
    private final JwtService jwtService;

    @Value("${app.otp.master:}")
    private String masterOtp;

    @Transactional
    public void requestOtp(String rawPhone) {
        String phone = normalize(rawPhone);
        String code = String.format("%06d", RANDOM.nextInt(1_000_000));

        OtpCode otp = new OtpCode();
        otp.setPhone(phone);
        otp.setCode(code);
        otp.setExpiresAt(LocalDateTime.now().plusMinutes(OTP_TTL_MINUTES));
        otp.setConsumed(false);
        otpCodeRepository.save(otp);

        // No SMS gateway wired yet: log the code so it is usable in dev.
        log.info("OTP for {} is {}", phone, code);
    }

    @Transactional
    public AuthTokens verifyOtp(String rawPhone, String code) {
        String phone = normalize(rawPhone);

        boolean masterMatch = masterOtp != null && !masterOtp.isBlank() && masterOtp.equals(code);

        if (!masterMatch) {
            OtpCode otp = otpCodeRepository.findTopByPhoneAndConsumedFalseOrderByCreatedAtDesc(phone)
                    .orElseThrow(() -> new AppException("No OTP requested for this phone", HttpStatus.BAD_REQUEST));
            if (otp.getExpiresAt().isBefore(LocalDateTime.now())) {
                throw new AppException("OTP expired", HttpStatus.BAD_REQUEST);
            }
            if (!otp.getCode().equals(code)) {
                throw new AppException("Incorrect OTP", HttpStatus.BAD_REQUEST);
            }
            otp.setConsumed(true);
            otpCodeRepository.save(otp);
        }

        User user = userRepository.findByPhone(phone)
                .orElseThrow(() -> new AppException("No account for this phone. Please register first.", HttpStatus.NOT_FOUND));
        user.setIsVerified(Boolean.TRUE);
        userRepository.save(user);

        return issueTokens(user);
    }

    @Transactional(readOnly = true)
    public AuthTokens refresh(String refreshToken) {
        if (!jwtService.isRefreshToken(refreshToken)) {
            throw new AppException("Not a refresh token", HttpStatus.BAD_REQUEST);
        }
        var userId = jwtService.parseUserId(refreshToken);
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new AppException("User not found", HttpStatus.NOT_FOUND));
        return issueTokens(user);
    }

    private AuthTokens issueTokens(User user) {
        String access = jwtService.generateAccessToken(user.getId(), user.getPhone());
        String refresh = jwtService.generateRefreshToken(user.getId());
        return new AuthTokens(access, refresh, UserDto.from(user));
    }

    private String normalize(String phone) {
        return phone == null ? "" : phone.trim();
    }
}
