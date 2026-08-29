package com.apsconnect.api.notification;

import com.apsconnect.api.common.response.ApiResponse;
import com.apsconnect.api.common.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/notifications")
@RequiredArgsConstructor
public class NotificationController {

    private final NotificationService notificationService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<NotificationDto>>> list() {
        return ResponseEntity.ok(ApiResponse.success(notificationService.list(SecurityUtils.currentUserId())));
    }

    @GetMapping("/unread-count")
    public ResponseEntity<ApiResponse<Map<String, Long>>> unreadCount() {
        return ResponseEntity.ok(ApiResponse.success(
                Map.of("count", notificationService.unreadCount(SecurityUtils.currentUserId()))));
    }

    @PostMapping("/{notificationId}/read")
    public ResponseEntity<ApiResponse<Void>> markRead(@PathVariable UUID notificationId) {
        notificationService.markRead(SecurityUtils.currentUserId(), notificationId);
        return ResponseEntity.ok(ApiResponse.success(null, "Marked read"));
    }

    @PostMapping("/read-all")
    public ResponseEntity<ApiResponse<Void>> markAllRead() {
        notificationService.markAllRead(SecurityUtils.currentUserId());
        return ResponseEntity.ok(ApiResponse.success(null, "All marked read"));
    }
}
