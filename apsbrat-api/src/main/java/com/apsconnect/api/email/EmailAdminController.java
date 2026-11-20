package com.apsconnect.api.email;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.common.response.ApiResponse;
import com.apsconnect.api.common.security.SecurityUtils;
import com.apsconnect.api.user.User;
import com.apsconnect.api.user.UserRepository;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Size;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Operator tools for email delivery. ADMIN only (see SecurityConfig): the test
 * endpoint sends a real email, so it must never be reachable by ordinary users.
 */
@RestController
@RequestMapping("/api/v1/admin/email")
@RequiredArgsConstructor
public class EmailAdminController {

    /** {@code to} is optional: left out, the test goes to the admin's own account email. */
    public record TestEmailRequest(@Email @Size(max = 254) String to) {
    }

    private final EmailService emailService;
    private final UserRepository userRepository;

    /** Is the key set and valid, is the sender verified? Calls Brevo, sends nothing. */
    @GetMapping("/health")
    public ResponseEntity<ApiResponse<EmailHealth>> health() {
        return ResponseEntity.ok(ApiResponse.success(emailService.health()));
    }

    /** Sends a test email (5 an hour). A provider problem comes back as {@code sent:false} with a reason. */
    @PostMapping("/test")
    public ResponseEntity<ApiResponse<EmailService.TestResult>> test(
            @Valid @RequestBody(required = false) TestEmailRequest request) {
        var adminId = SecurityUtils.currentUserId();
        String to = request == null || request.to() == null || request.to().isBlank()
                ? userRepository.findById(adminId).map(User::getEmail).orElse(null)
                : request.to().trim();
        if (to == null || to.isBlank()) {
            throw new AppException("Give an address in \"to\": your account has no email.", HttpStatus.BAD_REQUEST);
        }
        return ResponseEntity.ok(ApiResponse.success(emailService.sendTest(to, adminId)));
    }
}
