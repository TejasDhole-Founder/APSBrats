package com.apsconnect.api.safety;

import com.apsconnect.api.common.response.ApiResponse;
import com.apsconnect.api.common.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
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
@RequestMapping("/api/v1/admin")
@RequiredArgsConstructor
public class AdminController {

    private final AdminService adminService;

    @GetMapping("/reports")
    public ResponseEntity<ApiResponse<List<ReportDto>>> reports(
            @RequestParam(required = false) String status) {
        return ResponseEntity.ok(ApiResponse.success(adminService.listReports(status)));
    }

    @PostMapping("/reports/{reportId}/resolve")
    public ResponseEntity<ApiResponse<Void>> resolveReport(
            @PathVariable UUID reportId,
            @RequestBody AdminRequests.ResolveReportRequest request) {
        adminService.resolveReport(SecurityUtils.currentUserId(), reportId, request.status(), request.reason());
        return ResponseEntity.ok(ApiResponse.success(null, "Report updated"));
    }

    @PostMapping("/users/{userId}/suspend")
    public ResponseEntity<ApiResponse<Void>> suspend(
            @PathVariable UUID userId,
            @RequestBody AdminRequests.SuspendRequest request) {
        adminService.suspendUser(SecurityUtils.currentUserId(), userId, request.days(), request.reason());
        return ResponseEntity.ok(ApiResponse.success(null, "User suspended"));
    }

    @PostMapping("/users/{userId}/ban")
    public ResponseEntity<ApiResponse<Void>> ban(
            @PathVariable UUID userId,
            @RequestBody AdminRequests.BanRequest request) {
        adminService.banUser(SecurityUtils.currentUserId(), userId, request.reason());
        return ResponseEntity.ok(ApiResponse.success(null, "User banned"));
    }

    @PostMapping("/users/{userId}/reinstate")
    public ResponseEntity<ApiResponse<Void>> reinstate(@PathVariable UUID userId) {
        adminService.reinstateUser(SecurityUtils.currentUserId(), userId);
        return ResponseEntity.ok(ApiResponse.success(null, "User reinstated"));
    }

    @PostMapping("/users/{userId}/role")
    public ResponseEntity<ApiResponse<Void>> setRole(
            @PathVariable UUID userId,
            @RequestBody AdminRequests.SetRoleRequest request) {
        adminService.setRole(SecurityUtils.currentUserId(), userId, request.role());
        return ResponseEntity.ok(ApiResponse.success(null, "Role updated"));
    }

    @PostMapping("/communities/{communityId}/members/{userId}/remove")
    public ResponseEntity<ApiResponse<Void>> removeMember(
            @PathVariable UUID communityId,
            @PathVariable UUID userId,
            @RequestBody(required = false) AdminRequests.BanRequest request) {
        String reason = request != null ? request.reason() : null;
        adminService.removeCommunityMember(SecurityUtils.currentUserId(), communityId, userId, reason);
        return ResponseEntity.ok(ApiResponse.success(null, "Member removed"));
    }

    @GetMapping("/actions")
    public ResponseEntity<ApiResponse<List<ModerationAction>>> actions(
            @RequestParam(defaultValue = "50") int limit) {
        return ResponseEntity.ok(ApiResponse.success(adminService.recentActions(limit)));
    }
}
