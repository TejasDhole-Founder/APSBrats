package com.apsconnect.api.community;

import com.apsconnect.api.common.response.ApiResponse;
import com.apsconnect.api.common.security.SecurityUtils;
import com.apsconnect.api.search.PeopleSearchService;
import com.apsconnect.api.user.PersonDto;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/communities")
@RequiredArgsConstructor
public class CommunityController {

    private final CommunityService communityService;
    private final PeopleSearchService peopleSearchService;

    @GetMapping("/mine")
    public ResponseEntity<ApiResponse<MyCommunitiesDto>> mine() {
        return ResponseEntity.ok(ApiResponse.success(communityService.mine(SecurityUtils.currentUserId())));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<CommunityDto>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.success(communityService.get(SecurityUtils.currentUserId(), id)));
    }

    @PostMapping("/{id}/join")
    public ResponseEntity<ApiResponse<CommunityDto>> join(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.success(communityService.join(SecurityUtils.currentUserId(), id)));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<CommunityDto>> create(@Valid @RequestBody CreateCommunityRequest request) {
        return ResponseEntity.ok(ApiResponse.success(communityService.create(SecurityUtils.currentUserId(), request)));
    }

    @GetMapping("/discover")
    public ResponseEntity<ApiResponse<List<CommunityDto>>> discover(@RequestParam(defaultValue = "") String q) {
        return ResponseEntity.ok(ApiResponse.success(communityService.discover(SecurityUtils.currentUserId(), q)));
    }

    @GetMapping("/{id}/requests")
    public ResponseEntity<ApiResponse<List<JoinRequestDto>>> requests(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.success(communityService.requests(SecurityUtils.currentUserId(), id)));
    }

    @PostMapping("/{id}/requests/{userId}/approve")
    public ResponseEntity<ApiResponse<Void>> approve(@PathVariable UUID id, @PathVariable UUID userId) {
        communityService.approve(SecurityUtils.currentUserId(), id, userId);
        return ResponseEntity.ok(ApiResponse.success(null, "Request approved"));
    }

    @PostMapping("/{id}/requests/{userId}/reject")
    public ResponseEntity<ApiResponse<Void>> reject(@PathVariable UUID id, @PathVariable UUID userId) {
        communityService.reject(SecurityUtils.currentUserId(), id, userId);
        return ResponseEntity.ok(ApiResponse.success(null, "Request rejected"));
    }

    /**
     * Member directory: name search plus a batch filter. Visible to whoever can read
     * the community's posts. In a school community the batch is at that school.
     */
    @GetMapping("/{id}/members")
    public ResponseEntity<ApiResponse<List<PersonDto>>> members(
            @PathVariable UUID id,
            @RequestParam(defaultValue = "") String q,
            @RequestParam(required = false) Short batch,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "" + PeopleSearchService.DEFAULT_PAGE_SIZE) int size) {
        UUID me = SecurityUtils.currentUserId();
        Community community = communityService.requireReadable(me, id);
        var filters = new PeopleSearchService.Filters(
                batch == null ? null : community.getSchoolId(), batch, null, null, null, null, null);
        return ResponseEntity.ok(ApiResponse.success(
                peopleSearchService.search(me, q, filters, false, id, page, size)));
    }

    @DeleteMapping("/{id}/members/{userId}")
    public ResponseEntity<ApiResponse<Void>> removeMember(@PathVariable UUID id, @PathVariable UUID userId) {
        communityService.removeMemberAsOwner(SecurityUtils.currentUserId(), id, userId);
        return ResponseEntity.ok(ApiResponse.success(null, "Member removed"));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable UUID id) {
        communityService.delete(SecurityUtils.currentUserId(), id);
        return ResponseEntity.ok(ApiResponse.success(null, "Community deleted"));
    }

    @DeleteMapping("/{id}/members/me")
    public ResponseEntity<ApiResponse<Void>> leave(@PathVariable UUID id) {
        communityService.leave(SecurityUtils.currentUserId(), id);
        return ResponseEntity.ok(ApiResponse.success(null, "Left the community"));
    }
}