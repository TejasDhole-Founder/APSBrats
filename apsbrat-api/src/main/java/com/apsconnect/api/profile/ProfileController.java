package com.apsconnect.api.profile;

import com.apsconnect.api.common.response.ApiResponse;
import com.apsconnect.api.common.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/profiles")
@RequiredArgsConstructor
public class ProfileController {

    private final ProfileService profileService;

    @GetMapping("/{username}")
    public ResponseEntity<ApiResponse<ProfileDto>> getByUsername(@PathVariable String username) {
        return ResponseEntity.ok(ApiResponse.success(
                profileService.getByUsername(SecurityUtils.currentUserId(), username)));
    }
}
