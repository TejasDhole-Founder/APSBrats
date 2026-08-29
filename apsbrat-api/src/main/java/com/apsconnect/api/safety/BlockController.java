package com.apsconnect.api.safety;

import com.apsconnect.api.common.response.ApiResponse;
import com.apsconnect.api.common.security.SecurityUtils;
import com.apsconnect.api.user.PersonDto;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
public class BlockController {

    private final BlockService blockService;

    @PostMapping("/{userId}/block")
    public ResponseEntity<ApiResponse<Void>> block(@PathVariable UUID userId) {
        blockService.block(SecurityUtils.currentUserId(), userId);
        return ResponseEntity.ok(ApiResponse.success(null, "User blocked"));
    }

    @DeleteMapping("/{userId}/block")
    public ResponseEntity<ApiResponse<Void>> unblock(@PathVariable UUID userId) {
        blockService.unblock(SecurityUtils.currentUserId(), userId);
        return ResponseEntity.ok(ApiResponse.success(null, "User unblocked"));
    }

    @GetMapping("/me/blocks")
    public ResponseEntity<ApiResponse<List<PersonDto>>> myBlocks() {
        return ResponseEntity.ok(ApiResponse.success(blockService.myBlocks(SecurityUtils.currentUserId())));
    }
}
