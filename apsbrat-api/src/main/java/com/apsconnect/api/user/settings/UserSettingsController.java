package com.apsconnect.api.user.settings;

import com.apsconnect.api.common.response.ApiResponse;
import com.apsconnect.api.common.security.SecurityUtils;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/users/me/settings")
@RequiredArgsConstructor
public class UserSettingsController {

    private final UserSettingsService settingsService;

    @GetMapping
    public ResponseEntity<ApiResponse<UserSettingsDto>> get() {
        return ResponseEntity.ok(ApiResponse.success(settingsService.get(SecurityUtils.currentUserId())));
    }

    @PutMapping
    public ResponseEntity<ApiResponse<UserSettingsDto>> update(@Valid @RequestBody UpdateUserSettingsRequest request) {
        return ResponseEntity.ok(ApiResponse.success(
                settingsService.update(SecurityUtils.currentUserId(), request), "Settings updated"));
    }
}
