package com.apsconnect.api.auth;

import com.apsconnect.api.common.exception.AppException;
import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseToken;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import java.io.FileInputStream;
import java.io.IOException;

/**
 * Verifies the Firebase ID token the app sends after an on-device Google sign-in.
 * Lazily initialised from the service-account JSON at
 * {@code app.firebase.credentials-path} — until that file exists (see README /
 * deployment notes for where to get it from the Firebase console), Google
 * sign-in fails cleanly with a clear error instead of the app refusing to start.
 */
@Component
@RequiredArgsConstructor
public class FirebaseAuthVerifier {

    private static final Logger log = LoggerFactory.getLogger(FirebaseAuthVerifier.class);

    @Value("${app.firebase.credentials-path:}")
    private String credentialsPath;

    private volatile FirebaseApp app;

    /** Email, full name (may be null) and picture URL (may be null) from a verified token. */
    public record GoogleIdentity(String email, String name, String pictureUrl) {
    }

    public GoogleIdentity verify(String idToken) {
        try {
            FirebaseToken decoded = FirebaseAuth.getInstance(app()).verifyIdToken(idToken);
            if (decoded.getEmail() == null || !Boolean.TRUE.equals(decoded.isEmailVerified())) {
                throw new AppException("Google account has no verified email", HttpStatus.BAD_REQUEST);
            }
            return new GoogleIdentity(decoded.getEmail().toLowerCase(), decoded.getName(), decoded.getPicture());
        } catch (AppException e) {
            throw e;
        } catch (Exception e) {
            log.warn("Google sign-in token rejected: {}", e.getMessage());
            throw new AppException("Could not verify Google sign-in", HttpStatus.UNAUTHORIZED);
        }
    }

    private FirebaseApp app() {
        FirebaseApp existing = app;
        if (existing != null) {
            return existing;
        }
        synchronized (this) {
            if (app != null) {
                return app;
            }
            if (credentialsPath == null || credentialsPath.isBlank()) {
                throw new AppException(
                        "Google sign-in is not configured yet on this server", HttpStatus.SERVICE_UNAVAILABLE);
            }
            try (FileInputStream in = new FileInputStream(credentialsPath)) {
                FirebaseOptions options = FirebaseOptions.builder()
                        .setCredentials(GoogleCredentials.fromStream(in))
                        .build();
                app = FirebaseApp.getApps().isEmpty() ? FirebaseApp.initializeApp(options) : FirebaseApp.getInstance();
                return app;
            } catch (IOException e) {
                throw new AppException(
                        "Google sign-in is misconfigured on this server", HttpStatus.SERVICE_UNAVAILABLE);
            }
        }
    }
}
