package com.apsconnect.api.user.social;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.common.response.ApiResponse;
import com.apsconnect.api.common.security.SecurityUtils;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
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
@RequestMapping("/api/v1/users/{userId}/social-links")
@RequiredArgsConstructor
public class UserSocialLinkController {
    private final UserSocialLinkService userSocialLinkService;

    /** Someone's social links, filtered by their privacy settings (see the service). */
    @GetMapping
    public ResponseEntity<ApiResponse<List<UserSocialLinkDto>>> getSocialLinks(@PathVariable UUID userId) {
        return ResponseEntity.ok(ApiResponse.success(
                userSocialLinkService.getLinks(com.apsconnect.api.common.security.SecurityUtils.currentUserId(), userId)));
    }

    /** Writing is not — only the owner may change their own links. */
    @PutMapping("/{platform}")
    public ResponseEntity<ApiResponse<UserSocialLinkDto>> upsertSocialLink(
            @PathVariable UUID userId,
            @PathVariable SocialPlatform platform,
            @Valid @RequestBody UpsertUserSocialLinkRequest request) {
        if (!userId.equals(SecurityUtils.currentUserId())) {
            throw new AppException("You can only edit your own social links", HttpStatus.FORBIDDEN);
        }
        return ResponseEntity.ok(ApiResponse.success(userSocialLinkService.upsertLink(userId, platform, request)));
    }
}
