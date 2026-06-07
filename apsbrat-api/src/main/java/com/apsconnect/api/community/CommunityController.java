package com.apsconnect.api.community;

import com.apsconnect.api.common.response.ApiResponse;
import com.apsconnect.api.common.security.SecurityUtils;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/communities")
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
    public ResponseEntity<ApiResponse<List<CommunityMessageDto>>> messages(@PathVariable UUID communityId) {
        return ResponseEntity.ok(ApiResponse.success(communityService.messages(SecurityUtils.currentUserId(), communityId)));
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

    @PostMapping("/{communityId}/read")
    public ResponseEntity<ApiResponse<Void>> markRead(@PathVariable UUID communityId) {
        communityService.markRead(SecurityUtils.currentUserId(), communityId);
        return ResponseEntity.ok(ApiResponse.success(null, "Marked read"));
    }
}
