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

    /** My friends (accepted), A→Z. */
    @GetMapping
    public ResponseEntity<ApiResponse<List<PersonDto>>> myBatchmates() {
        return ResponseEntity.ok(ApiResponse.success(connectionService.listBatchmates(SecurityUtils.currentUserId())));
    }

    /** Requests waiting for me. */
    @GetMapping("/pending")
    public ResponseEntity<ApiResponse<List<PersonDto>>> pending() {
        return ResponseEntity.ok(ApiResponse.success(connectionService.listPending(SecurityUtils.currentUserId())));
    }

    /** Requests I sent that are still unanswered. */
    @GetMapping("/sent")
    public ResponseEntity<ApiResponse<List<PersonDto>>> sent() {
        return ResponseEntity.ok(ApiResponse.success(connectionService.listSent(SecurityUtils.currentUserId())));
    }

    @GetMapping("/{userId}/mutual")
    public ResponseEntity<ApiResponse<List<PersonDto>>> mutual(@PathVariable UUID userId) {
        return ResponseEntity.ok(ApiResponse.success(
                connectionService.listMutual(SecurityUtils.currentUserId(), userId)));
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

    /** Decline a request I received, withdraw one I sent, or remove a friend. */
    @DeleteMapping("/{userId}")
    public ResponseEntity<ApiResponse<Map<String, String>>> end(@PathVariable UUID userId) {
        ConnectionStatus result = connectionService.endConnection(SecurityUtils.currentUserId(), userId);
        return ResponseEntity.ok(ApiResponse.success(Map.of("status", result.name())));
    }
}
