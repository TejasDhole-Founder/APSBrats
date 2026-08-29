package com.apsconnect.api.community;

import com.apsconnect.api.common.response.ApiResponse;
import com.apsconnect.api.common.response.CursorPage;
import com.apsconnect.api.common.security.SecurityUtils;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/communities")
@RequiredArgsConstructor
public class CommunityController {

    private final CommunityService communityService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<CommunityDto>>> myCommunities() {
        return ResponseEntity.ok(ApiResponse.success(communityService.myCommunities(SecurityUtils.currentUserId())));
    }

    @GetMapping("/discover")
    public ResponseEntity<ApiResponse<List<DiscoverCommunityDto>>> discover() {
        return ResponseEntity.ok(ApiResponse.success(communityService.discover(SecurityUtils.currentUserId())));
    }

    @GetMapping("/{communityId}")
    public ResponseEntity<ApiResponse<CommunityDto>> get(@PathVariable UUID communityId) {
        return ResponseEntity.ok(ApiResponse.success(communityService.get(SecurityUtils.currentUserId(), communityId)));
    }

    @GetMapping("/{communityId}/messages")
    public ResponseEntity<ApiResponse<CursorPage<CommunityMessageDto>>> messages(
            @PathVariable UUID communityId,
            @RequestParam(required = false) String cursor,
            @RequestParam(defaultValue = "30") int limit) {
        return ResponseEntity.ok(ApiResponse.success(
                communityService.messages(SecurityUtils.currentUserId(), communityId, cursor, limit)));
    }

    @PostMapping("/{communityId}/messages")
    public ResponseEntity<ApiResponse<CommunityMessageDto>> send(
            @PathVariable UUID communityId,
            @Valid @RequestBody SendCommunityMessageRequest request) {
        return ResponseEntity.ok(ApiResponse.success(
                communityService.sendMessage(SecurityUtils.currentUserId(), communityId, request.body())));
    }

    @PostMapping("/{communityId}/join")
    public ResponseEntity<ApiResponse<Void>> join(@PathVariable UUID communityId) {
        communityService.join(SecurityUtils.currentUserId(), communityId);
        return ResponseEntity.ok(ApiResponse.success(null, "Joined community"));
    }

    @DeleteMapping("/{communityId}/members/me")
    public ResponseEntity<ApiResponse<Void>> leave(@PathVariable UUID communityId) {
        communityService.leave(SecurityUtils.currentUserId(), communityId);
        return ResponseEntity.ok(ApiResponse.success(null, "Left community"));
    }

    @PostMapping("/{communityId}/read")
    public ResponseEntity<ApiResponse<Void>> markRead(@PathVariable UUID communityId) {
        communityService.markRead(SecurityUtils.currentUserId(), communityId);
        return ResponseEntity.ok(ApiResponse.success(null, "Marked read"));
    }
}
