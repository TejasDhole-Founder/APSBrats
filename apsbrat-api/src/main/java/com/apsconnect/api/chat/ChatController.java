package com.apsconnect.api.chat;

import com.apsconnect.api.common.response.ApiResponse;
import com.apsconnect.api.common.security.SecurityUtils;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/conversations")
@RequiredArgsConstructor
public class ChatController {

    private final ChatService chatService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<ConversationDto>>> list() {
        return ResponseEntity.ok(ApiResponse.success(chatService.listConversations(SecurityUtils.currentUserId())));
    }

    @PostMapping("/with/{userId}")
    public ResponseEntity<ApiResponse<ConversationDto>> openWith(@PathVariable UUID userId) {
        return ResponseEntity.ok(ApiResponse.success(
                chatService.getOrCreateWith(SecurityUtils.currentUserId(), userId)));
    }

    @GetMapping("/{conversationId}/messages")
    public ResponseEntity<ApiResponse<List<ChatMessageDto>>> messages(@PathVariable UUID conversationId) {
        return ResponseEntity.ok(ApiResponse.success(
                chatService.messages(SecurityUtils.currentUserId(), conversationId)));
    }

    @PostMapping("/{conversationId}/messages")
    public ResponseEntity<ApiResponse<ChatMessageDto>> send(
            @PathVariable UUID conversationId,
            @Valid @RequestBody SendMessageRequest request) {
        return ResponseEntity.ok(ApiResponse.success(
                chatService.send(SecurityUtils.currentUserId(), conversationId, request.body())));
    }

    @PostMapping("/{conversationId}/read")
    public ResponseEntity<ApiResponse<Void>> markRead(@PathVariable UUID conversationId) {
        chatService.markRead(SecurityUtils.currentUserId(), conversationId);
        return ResponseEntity.ok(ApiResponse.success(null, "Marked read"));
    }
}
