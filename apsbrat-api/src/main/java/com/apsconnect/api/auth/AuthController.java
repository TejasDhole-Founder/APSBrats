package com.apsconnect.api.auth;

import com.apsconnect.api.common.response.ApiResponse;
import com.apsconnect.api.common.security.SecurityUtils;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @PostMapping("/request-otp")
    public ResponseEntity<ApiResponse<Void>> requestOtp(@Valid @RequestBody RequestOtpRequest request,
                                                        HttpServletRequest http) {
        authService.requestOtp(request.email(), clientIp(http));
        return ResponseEntity.ok(ApiResponse.success(null, "OTP sent"));
    }

    /** Logs in if this email already has an account, otherwise creates a bare one for onboarding to fill in. */
    @PostMapping("/verify-otp")
    public ResponseEntity<ApiResponse<AuthTokens>> verifyOtp(@Valid @RequestBody VerifyOtpRequest request) {
        return ResponseEntity.ok(ApiResponse.success(authService.verifyOtp(request.email(), request.code()), "Logged in"));
    }

    /** Same log-in-or-create behaviour as verify-otp, keyed by the Google account's email. */
    @PostMapping("/google")
    public ResponseEntity<ApiResponse<AuthTokens>> google(@Valid @RequestBody GoogleSignInRequest request) {
        return ResponseEntity.ok(ApiResponse.success(authService.signInWithGoogle(request.idToken()), "Logged in"));
    }

    @PostMapping("/refresh")
    public ResponseEntity<ApiResponse<AuthTokens>> refresh(@Valid @RequestBody RefreshTokenRequest request) {
        return ResponseEntity.ok(ApiResponse.success(authService.refresh(request.refreshToken())));
    }

    @PostMapping("/logout")
    public ResponseEntity<ApiResponse<Void>> logout(@Valid @RequestBody RefreshTokenRequest request) {
        authService.logout(request.refreshToken());
        return ResponseEntity.ok(ApiResponse.success(null, "Logged out"));
    }

    /** Signs this account out everywhere: every refresh token dropped, every access token rejected. */
    @PostMapping("/logout-all")
    public ResponseEntity<ApiResponse<Void>> logoutAll() {
        authService.revokeAllFor(SecurityUtils.currentUserId());
        return ResponseEntity.ok(ApiResponse.success(null, "Logged out of all devices"));
    }

    /**
     * Tomcat's RemoteIpValve (server.forward-headers-strategy: native) has already replaced
     * this with the X-Forwarded-For client when the request came through a trusted proxy.
     * Reading the header here directly would let any caller pick their own IP.
     */
    private String clientIp(HttpServletRequest request) {
        return request.getRemoteAddr();
    }
}
