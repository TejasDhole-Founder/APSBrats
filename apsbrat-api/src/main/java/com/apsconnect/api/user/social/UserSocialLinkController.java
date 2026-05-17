package com.apsconnect.api.user.social;

import com.apsconnect.api.common.response.ApiResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/users/{userId}/social-links")
@RequiredArgsConstructor
public class UserSocialLinkController {
    private final UserSocialLinkService userSocialLinkService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<UserSocialLinkDto>>> getSocialLinks(@PathVariable UUID userId) {
        return ResponseEntity.ok(ApiResponse.success(userSocialLinkService.getLinks(userId)));
    }

    @PutMapping("/{platform}")
    public ResponseEntity<ApiResponse<UserSocialLinkDto>> upsertSocialLink(
            @PathVariable UUID userId,
            @PathVariable SocialPlatform platform,
            @Valid @RequestBody UpsertUserSocialLinkRequest request) {
        return ResponseEntity.ok(ApiResponse.success(userSocialLinkService.upsertLink(userId, platform, request)));
    }
}
