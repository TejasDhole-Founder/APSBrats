package com.apsconnect.api.circle;

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
import java.util.UUID;

/** The people screen at rest: my counts, my classmates, my schoolmates. */
@RestController
@RequestMapping("/api/v1/users/me/circle")
@RequiredArgsConstructor
public class CircleController {

    private final CircleService circleService;

    @GetMapping("/summary")
    public ResponseEntity<ApiResponse<CircleSummaryDto>> summary() {
        return ResponseEntity.ok(ApiResponse.success(circleService.summary(SecurityUtils.currentUserId())));
    }

    @GetMapping("/classmates")
    public ResponseEntity<ApiResponse<List<PersonDto>>> classmates(
            @RequestParam(required = false) UUID entryId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "" + CircleService.PAGE_SIZE) int size) {
        return ResponseEntity.ok(ApiResponse.success(
                circleService.classmates(SecurityUtils.currentUserId(), entryId, page, size)));
    }

    @GetMapping("/schoolmates")
    public ResponseEntity<ApiResponse<List<PersonDto>>> schoolmates(
            @RequestParam(required = false) UUID entryId,
            @RequestParam(defaultValue = "false") boolean batchOnly,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "" + CircleService.PAGE_SIZE) int size) {
        return ResponseEntity.ok(ApiResponse.success(
                circleService.schoolmates(SecurityUtils.currentUserId(), entryId, batchOnly, page, size)));
    }
}
