package com.apsconnect.api.community;

import com.apsconnect.api.chat.SendChatMessageRequest;
import com.apsconnect.api.common.response.ApiResponse;
import com.apsconnect.api.common.response.CursorPage;
import com.apsconnect.api.common.security.SecurityUtils;
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

import java.util.UUID;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class CommunityChatController {

    private final CommunityChatService chatService;

    @GetMapping("/communities/mine/chats")
    public ResponseEntity<ApiResponse<java.util.List<CommunityChatService.ChatListItem>>> myChats() {
        return ResponseEntity.ok(ApiResponse.success(chatService.myChats(SecurityUtils.currentUserId())));
    }

    @GetMapping("/communities/{id}/chat")
    public ResponseEntity<ApiResponse<CommunityChatService.Summary>> summary(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.success(chatService.summary(SecurityUtils.currentUserId(), id)));
    }

    @GetMapping("/communities/{id}/chat/messages")
    public ResponseEntity<ApiResponse<CursorPage<CommunityMessageDto>>> messages(
            @PathVariable UUID id,
            @RequestParam(required = false) String cursor,
            @RequestParam(defaultValue = "30") int limit) {
        return ResponseEntity.ok(ApiResponse.success(
                chatService.messages(SecurityUtils.currentUserId(), id, cursor, limit)));
    }

    @PostMapping("/communities/{id}/chat/messages")
    public ResponseEntity<ApiResponse<CommunityMessageDto>> send(
            @PathVariable UUID id, @Valid @RequestBody SendChatMessageRequest request) {
        return ResponseEntity.ok(ApiResponse.success(chatService.send(SecurityUtils.currentUserId(), id, request)));
    }

    @PostMapping("/communities/{id}/chat/read")
    public ResponseEntity<ApiResponse<Void>> markRead(@PathVariable UUID id) {
        chatService.markRead(SecurityUtils.currentUserId(), id);
        return ResponseEntity.ok(ApiResponse.success(null, "Marked read"));
    }

    @DeleteMapping("/community-messages/{id}")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable UUID id) {
        chatService.delete(SecurityUtils.currentUserId(), id);
        return ResponseEntity.ok(ApiResponse.success(null, "Message deleted"));
    }
}
