package com.apsconnect.api.user.history;

import com.apsconnect.api.common.response.ApiResponse;
import com.apsconnect.api.profile.SchoolHistoryDto;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/users/{userId}/school-history")
@RequiredArgsConstructor
public class UserSchoolHistoryController {
    private final UserSchoolHistoryService userSchoolHistoryService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<SchoolHistoryDto>>> getSchoolHistory(@PathVariable UUID userId) {
        return ResponseEntity.ok(ApiResponse.success(userSchoolHistoryService.getSchoolHistory(userId)));
    }

    @PostMapping("/bulk")
    public ResponseEntity<ApiResponse<Void>> replaceSchoolHistory(
            @PathVariable UUID userId,
            @Valid @RequestBody SaveSchoolHistoryRequest request) {
        userSchoolHistoryService.replaceSchoolHistory(userId, request);
        return ResponseEntity.ok(ApiResponse.success(null, "School history saved"));
    }
}
