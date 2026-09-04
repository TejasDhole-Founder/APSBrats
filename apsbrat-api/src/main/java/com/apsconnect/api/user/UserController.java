package com.apsconnect.api.user;

import com.apsconnect.api.common.response.ApiResponse;
import com.apsconnect.api.common.security.SecurityUtils;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

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
        return ResponseEntity.ok(ApiResponse.success(userService.getUsers(page, size)));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<UserDto>> registerUser(@Valid @RequestBody RegisterUserRequest request) {
        return ResponseEntity.ok(ApiResponse.success(userService.registerUser(request), "User registered successfully"));
    }

    @GetMapping("/username-available")
    public ResponseEntity<ApiResponse<AvailabilityDto>> usernameAvailable(@RequestParam String username) {
        return ResponseEntity.ok(ApiResponse.success(userService.usernameAvailability(username)));
    }

    @GetMapping("/phone-available")
    public ResponseEntity<ApiResponse<AvailabilityDto>> phoneAvailable(@RequestParam String phone) {
        return ResponseEntity.ok(ApiResponse.success(userService.phoneAvailability(phone)));
    }

    @PutMapping("/{userId}/password")
    public ResponseEntity<ApiResponse<Void>> changePassword(
            @PathVariable UUID userId,
            @Valid @RequestBody ChangePasswordRequest request) {
        userService.changePassword(userId, request);
        return ResponseEntity.ok(ApiResponse.success(null, "Password updated successfully"));
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
