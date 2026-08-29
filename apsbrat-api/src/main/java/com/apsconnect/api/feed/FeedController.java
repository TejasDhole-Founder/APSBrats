package com.apsconnect.api.feed;

import com.apsconnect.api.common.response.ApiResponse;
import com.apsconnect.api.common.security.SecurityUtils;
import com.apsconnect.api.user.PersonDto;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/feed")
@RequiredArgsConstructor
public class FeedController {

    private final FeedService feedService;

    @GetMapping("/activity")
    public ResponseEntity<ApiResponse<List<FeedEventDto>>> activity(
            @RequestParam(defaultValue = "20") int limit) {
        return ResponseEntity.ok(ApiResponse.success(feedService.activity(limit)));
    }

    @GetMapping("/recent-joins")
    public ResponseEntity<ApiResponse<List<PersonDto>>> recentJoins() {
        return ResponseEntity.ok(ApiResponse.success(feedService.recentJoins(SecurityUtils.currentUserId())));
    }

    @GetMapping("/banner")
    public ResponseEntity<ApiResponse<BatchmateBannerDto>> banner() {
        return ResponseEntity.ok(ApiResponse.success(feedService.banner(SecurityUtils.currentUserId())));
    }
}
