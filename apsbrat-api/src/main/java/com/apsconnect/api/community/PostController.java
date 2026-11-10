package com.apsconnect.api.community;

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
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class PostController {

    private final PostService postService;

    @GetMapping("/communities/{communityId}/posts")
    public ResponseEntity<ApiResponse<CursorPage<PostDto>>> list(
            @PathVariable UUID communityId,
            @RequestParam(defaultValue = "latest") String sort,
            @RequestParam(required = false) String cursor,
            @RequestParam(defaultValue = "20") int limit) {
        return ResponseEntity.ok(ApiResponse.success(
                postService.list(SecurityUtils.currentUserId(), communityId, sort, cursor, limit)));
    }

    @PostMapping("/communities/{communityId}/posts")
    public ResponseEntity<ApiResponse<PostDto>> create(
            @PathVariable UUID communityId, @Valid @RequestBody CreatePostRequest request) {
        return ResponseEntity.ok(ApiResponse.success(
                postService.create(SecurityUtils.currentUserId(), communityId, request)));
    }

    /** The Memories gallery. year and category are optional filters. */
    @GetMapping("/communities/{communityId}/memories")
    public ResponseEntity<ApiResponse<CursorPage<PostDto>>> memories(
            @PathVariable UUID communityId,
            @RequestParam(required = false) Short year,
            @RequestParam(required = false) MemoryCategory category,
            @RequestParam(required = false) String cursor,
            @RequestParam(defaultValue = "30") int limit) {
        return ResponseEntity.ok(ApiResponse.success(
                postService.memories(SecurityUtils.currentUserId(), communityId, year, category, cursor, limit)));
    }

    @GetMapping("/communities/{communityId}/memories/years")
    public ResponseEntity<ApiResponse<List<Short>>> memoryYears(@PathVariable UUID communityId) {
        return ResponseEntity.ok(ApiResponse.success(
                postService.memoryYears(SecurityUtils.currentUserId(), communityId)));
    }

    /** Home tab: newest posts from every community I've joined. */
    @GetMapping("/feed/home")
    public ResponseEntity<ApiResponse<CursorPage<PostDto>>> home(
            @RequestParam(required = false) String cursor,
            @RequestParam(defaultValue = "20") int limit) {
        return ResponseEntity.ok(ApiResponse.success(
                postService.homeFeed(SecurityUtils.currentUserId(), cursor, limit)));
    }

    @GetMapping("/posts/{id}")
    public ResponseEntity<ApiResponse<PostDto>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.success(postService.get(SecurityUtils.currentUserId(), id)));
    }

    @DeleteMapping("/posts/{id}")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable UUID id) {
        postService.delete(SecurityUtils.currentUserId(), id);
        return ResponseEntity.ok(ApiResponse.success(null, "Post deleted"));
    }

    @PutMapping("/posts/{id}/like")
    public ResponseEntity<ApiResponse<PostDto>> like(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.success(postService.like(SecurityUtils.currentUserId(), id)));
    }

    @DeleteMapping("/posts/{id}/like")
    public ResponseEntity<ApiResponse<PostDto>> unlike(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.success(postService.unlike(SecurityUtils.currentUserId(), id)));
    }

    @PutMapping("/posts/{id}/pin")
    public ResponseEntity<ApiResponse<PostDto>> pin(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.success(postService.setPinned(SecurityUtils.currentUserId(), id, true)));
    }

    @DeleteMapping("/posts/{id}/pin")
    public ResponseEntity<ApiResponse<PostDto>> unpin(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.success(postService.setPinned(SecurityUtils.currentUserId(), id, false)));
    }

    @GetMapping("/posts/{id}/comments")
    public ResponseEntity<ApiResponse<CursorPage<CommentDto>>> comments(
            @PathVariable UUID id,
            @RequestParam(required = false) String cursor,
            @RequestParam(defaultValue = "30") int limit) {
        return ResponseEntity.ok(ApiResponse.success(
                postService.comments(SecurityUtils.currentUserId(), id, cursor, limit)));
    }

    @PostMapping("/posts/{id}/comments")
    public ResponseEntity<ApiResponse<CommentDto>> addComment(
            @PathVariable UUID id, @Valid @RequestBody CreateCommentRequest request) {
        return ResponseEntity.ok(ApiResponse.success(
                postService.addComment(SecurityUtils.currentUserId(), id, request)));
    }

    @DeleteMapping("/comments/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteComment(@PathVariable UUID id) {
        postService.deleteComment(SecurityUtils.currentUserId(), id);
        return ResponseEntity.ok(ApiResponse.success(null, "Comment deleted"));
    }
}
