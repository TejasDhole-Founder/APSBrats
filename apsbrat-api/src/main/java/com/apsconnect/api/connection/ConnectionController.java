package com.apsconnect.api.connection;

import com.apsconnect.api.common.response.ApiResponse;
import com.apsconnect.api.common.security.SecurityUtils;
import com.apsconnect.api.user.PersonDto;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/connections")
@RequiredArgsConstructor
public class ConnectionController {

    private final ConnectionService connectionService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<PersonDto>>> myBatchmates() {
        return ResponseEntity.ok(ApiResponse.success(connectionService.listBatchmates(SecurityUtils.currentUserId())));
    }

    @GetMapping("/pending")
    public ResponseEntity<ApiResponse<List<PersonDto>>> pending() {
        return ResponseEntity.ok(ApiResponse.success(connectionService.listPending(SecurityUtils.currentUserId())));
    }

    @GetMapping("/{userId}/status")
    public ResponseEntity<ApiResponse<Map<String, String>>> status(@PathVariable UUID userId) {
        String status = connectionService.statusWith(SecurityUtils.currentUserId(), userId);
        return ResponseEntity.ok(ApiResponse.success(Map.of("status", status)));
    }

    @PostMapping("/{userId}")
    public ResponseEntity<ApiResponse<Void>> request(@PathVariable UUID userId) {
        connectionService.requestConnection(SecurityUtils.currentUserId(), userId);
        return ResponseEntity.ok(ApiResponse.success(null, "Connection requested"));
    }

    @PutMapping("/{userId}/accept")
    public ResponseEntity<ApiResponse<Void>> accept(@PathVariable UUID userId) {
        connectionService.acceptConnection(SecurityUtils.currentUserId(), userId);
        return ResponseEntity.ok(ApiResponse.success(null, "Connection accepted"));
    }
}
