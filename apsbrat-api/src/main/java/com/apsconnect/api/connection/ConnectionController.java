package com.apsconnect.api.connection;

import com.apsconnect.api.common.response.ApiResponse;
import com.apsconnect.api.common.response.CursorPage;
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
    private final ConnectionQueryService queryService;

    /** My friends (accepted), A→Z. */
    @GetMapping
    public ResponseEntity<ApiResponse<List<PersonDto>>> myBatchmates() {
        return ResponseEntity.ok(ApiResponse.success(queryService.listBatchmates(SecurityUtils.currentUserId())));
    }

    /** The same list, one page at a time: pass the previous page's nextCursor back as cursor. */
    @GetMapping("/page")
    public ResponseEntity<ApiResponse<CursorPage<PersonDto>>> myConnectionsPage(
            @RequestParam(required = false) String cursor,
            @RequestParam(defaultValue = "0") int limit) {
        return ResponseEntity.ok(ApiResponse.success(
                queryService.pageConnections(SecurityUtils.currentUserId(), cursor, limit)));
    }

    /** Requests waiting for me. */
    @GetMapping("/pending")
    public ResponseEntity<ApiResponse<List<PersonDto>>> pending() {
        return ResponseEntity.ok(ApiResponse.success(queryService.listPending(SecurityUtils.currentUserId())));
    }

    /** Requests waiting for me, newest first, one page at a time. */
    @GetMapping("/pending/page")
    public ResponseEntity<ApiResponse<CursorPage<PersonDto>>> pendingPage(
            @RequestParam(required = false) String cursor,
            @RequestParam(defaultValue = "0") int limit) {
        return ResponseEntity.ok(ApiResponse.success(
                queryService.pageReceived(SecurityUtils.currentUserId(), cursor, limit)));
    }

    /** Requests I sent that are still unanswered, newest first, one page at a time. */
    @GetMapping("/sent/page")
    public ResponseEntity<ApiResponse<CursorPage<PersonDto>>> sentPage(
            @RequestParam(required = false) String cursor,
            @RequestParam(defaultValue = "0") int limit) {
        return ResponseEntity.ok(ApiResponse.success(
                queryService.pageSent(SecurityUtils.currentUserId(), cursor, limit)));
    }

    /** Requests I sent that are still unanswered. */
    @GetMapping("/sent")
    public ResponseEntity<ApiResponse<List<PersonDto>>> sent() {
        return ResponseEntity.ok(ApiResponse.success(queryService.listSent(SecurityUtils.currentUserId())));
    }

    @GetMapping("/{userId}/mutual")
    public ResponseEntity<ApiResponse<List<PersonDto>>> mutual(@PathVariable UUID userId) {
        return ResponseEntity.ok(ApiResponse.success(
                queryService.listMutual(SecurityUtils.currentUserId(), userId)));
    }

    /** How many connections I share with this person. */
    @GetMapping("/{userId}/mutual/count")
    public ResponseEntity<ApiResponse<Map<String, Long>>> mutualCount(@PathVariable UUID userId) {
        long count = queryService.mutualCount(SecurityUtils.currentUserId(), userId);
        return ResponseEntity.ok(ApiResponse.success(Map.of("count", count)));
    }

    /** The shared connections, A→Z, one page at a time. */
    @GetMapping("/{userId}/mutual/page")
    public ResponseEntity<ApiResponse<CursorPage<PersonDto>>> mutualPage(
            @PathVariable UUID userId,
            @RequestParam(required = false) String cursor,
            @RequestParam(defaultValue = "0") int limit) {
        return ResponseEntity.ok(ApiResponse.success(
                queryService.pageMutual(SecurityUtils.currentUserId(), userId, cursor, limit)));
    }

    @GetMapping("/{userId}/status")
    public ResponseEntity<ApiResponse<Map<String, String>>> status(@PathVariable UUID userId) {
        String status = queryService.statusWith(SecurityUtils.currentUserId(), userId);
        return ResponseEntity.ok(ApiResponse.success(Map.of("status", status)));
    }

    /** What happened between me and this person (requested, accepted, removed, ...), oldest first. */
    @GetMapping("/{userId}/history")
    public ResponseEntity<ApiResponse<List<ConnectionEventDto>>> history(@PathVariable UUID userId) {
        return ResponseEntity.ok(ApiResponse.success(
                queryService.history(SecurityUtils.currentUserId(), userId)));
    }

    /** Ask to connect. If they had already asked me, it is accepted straight away (status ACCEPTED). */
    @PostMapping("/{userId}")
    public ResponseEntity<ApiResponse<Map<String, String>>> request(@PathVariable UUID userId) {
        ConnectionStatus result = connectionService.requestConnection(SecurityUtils.currentUserId(), userId);
        String message = result == ConnectionStatus.ACCEPTED ? "Connection accepted" : "Connection requested";
        return ResponseEntity.ok(ApiResponse.success(Map.of("status", result.name()), message));
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
