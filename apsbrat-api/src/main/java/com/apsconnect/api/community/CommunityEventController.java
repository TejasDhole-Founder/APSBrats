package com.apsconnect.api.community;

import com.apsconnect.api.common.response.ApiResponse;
import com.apsconnect.api.common.response.CursorPage;
import com.apsconnect.api.common.security.SecurityUtils;
import com.apsconnect.api.user.PersonDto;
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
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class CommunityEventController {

    private final CommunityEventService eventService;
    private final PostService postService;

    public record RsvpRequest(EventRsvp.Status status) {
    }

    /** when = upcoming (default) or past. */
    @GetMapping("/communities/{id}/events")
    public ResponseEntity<ApiResponse<CommunityEventService.EventList>> list(
            @PathVariable UUID id, @RequestParam(defaultValue = "upcoming") String when) {
        return ResponseEntity.ok(ApiResponse.success(
                eventService.list(SecurityUtils.currentUserId(), id, "past".equals(when))));
    }

    @PostMapping("/communities/{id}/events")
    public ResponseEntity<ApiResponse<EventDto>> create(
            @PathVariable UUID id, @Valid @RequestBody SaveEventRequest request) {
        return ResponseEntity.ok(ApiResponse.success(eventService.create(SecurityUtils.currentUserId(), id, request)));
    }

    @GetMapping("/events/{id}")
    public ResponseEntity<ApiResponse<EventDto>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.success(eventService.get(SecurityUtils.currentUserId(), id)));
    }

    @PutMapping("/events/{id}")
    public ResponseEntity<ApiResponse<EventDto>> update(
            @PathVariable UUID id, @Valid @RequestBody SaveEventRequest request) {
        return ResponseEntity.ok(ApiResponse.success(eventService.update(SecurityUtils.currentUserId(), id, request)));
    }

    @PostMapping("/events/{id}/cancel")
    public ResponseEntity<ApiResponse<EventDto>> cancel(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.success(eventService.cancel(SecurityUtils.currentUserId(), id)));
    }

    @PutMapping("/events/{id}/rsvp")
    public ResponseEntity<ApiResponse<EventDto>> rsvp(@PathVariable UUID id, @RequestBody RsvpRequest request) {
        return ResponseEntity.ok(ApiResponse.success(
                eventService.rsvp(SecurityUtils.currentUserId(), id, request.status())));
    }

    @DeleteMapping("/events/{id}/rsvp")
    public ResponseEntity<ApiResponse<EventDto>> clearRsvp(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.success(eventService.rsvp(SecurityUtils.currentUserId(), id, null)));
    }

    /** {"GOING": [...], "INTERESTED": [...]} */
    @GetMapping("/events/{id}/attendees")
    public ResponseEntity<ApiResponse<Map<String, List<PersonDto>>>> attendees(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.success(eventService.attendees(SecurityUtils.currentUserId(), id)));
    }

    /** Photos and posts members shared from the event, newest first. */
    @GetMapping("/events/{id}/posts")
    public ResponseEntity<ApiResponse<CursorPage<PostDto>>> posts(
            @PathVariable UUID id,
            @RequestParam(required = false) String cursor,
            @RequestParam(defaultValue = "20") int limit) {
        return ResponseEntity.ok(ApiResponse.success(
                postService.eventPosts(SecurityUtils.currentUserId(), id, cursor, limit)));
    }
}
