package com.apsconnect.api.user.history;

import com.apsconnect.api.common.response.ApiResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/users/{userId}/school-history")
@RequiredArgsConstructor
public class UserSchoolHistoryController {
    private final UserSchoolHistoryService userSchoolHistoryService;

    @PostMapping("/bulk")
    public ResponseEntity<ApiResponse<Void>> replaceSchoolHistory(
            @PathVariable UUID userId,
            @Valid @RequestBody SaveSchoolHistoryRequest request) {
        userSchoolHistoryService.replaceSchoolHistory(userId, request);
        return ResponseEntity.ok(ApiResponse.success(null, "School history saved"));
    }
}
