package com.apsconnect.api.user;

import com.apsconnect.api.common.response.ApiResponse;
import com.apsconnect.api.common.security.SecurityUtils;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
public class UserController {
    private final UserService userService;
    private final AccountService accountService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<PersonDto>>> getUsers(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        // Bounded: this must not be a way to download everyone.
        return ResponseEntity.ok(ApiResponse.success(
                userService.getUsers(Math.max(page, 0), Math.min(Math.max(size, 1), 50))));
    }

    @GetMapping("/username-available")
    public ResponseEntity<ApiResponse<AvailabilityDto>> usernameAvailable(@RequestParam String username) {
        return ResponseEntity.ok(ApiResponse.success(userService.usernameAvailability(username)));
    }

    @GetMapping("/me")
    public ResponseEntity<ApiResponse<UserDto>> getMe() {
        return ResponseEntity.ok(ApiResponse.success(userService.getMe(SecurityUtils.currentUserId())));
    }

    @PutMapping("/me")
    public ResponseEntity<ApiResponse<UserDto>> updateMe(@Valid @RequestBody UpdateProfileRequest request) {
        return ResponseEntity.ok(ApiResponse.success(
                userService.updateMe(SecurityUtils.currentUserId(), request), "Profile updated"));
    }

    @GetMapping("/me/export")
    public ResponseEntity<ApiResponse<AccountExportDto>> exportMyData() {
        return ResponseEntity.ok(ApiResponse.success(accountService.export(SecurityUtils.currentUserId())));
    }

    @DeleteMapping("/me")
    public ResponseEntity<ApiResponse<Void>> deleteMyAccount() {
        accountService.deleteAccount(SecurityUtils.currentUserId());
        return ResponseEntity.ok(ApiResponse.success(null, "Account deleted"));
    }
}
