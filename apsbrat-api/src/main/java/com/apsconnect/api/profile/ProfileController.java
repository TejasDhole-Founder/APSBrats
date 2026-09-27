package com.apsconnect.api.profile;

import com.apsconnect.api.common.response.ApiResponse;
import com.apsconnect.api.common.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/profiles")
@RequiredArgsConstructor
public class ProfileController {

    private final ProfileService profileService;

    // Profiles are addressed by opaque user id, never by username, so URLs
    // don't leak handles and accounts can't be enumerated by guessing names.
    @GetMapping("/{userId}")
    public ResponseEntity<ApiResponse<ProfileDto>> getById(@PathVariable UUID userId) {
        return ResponseEntity.ok(ApiResponse.success(
                profileService.getById(SecurityUtils.currentUserId(), userId)));
    }
}
