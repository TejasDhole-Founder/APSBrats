package com.apsconnect.api.career;

import com.apsconnect.api.common.response.ApiResponse;
import com.apsconnect.api.common.security.SecurityUtils;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class CareerController {

    private final CareerService careerService;

    /** Autocomplete for the company / college field. */
    @GetMapping("/organizations/search")
    public ResponseEntity<ApiResponse<List<OrganizationDto>>> search(
            @RequestParam OrgType type, @RequestParam String q) {
        return ResponseEntity.ok(ApiResponse.success(careerService.searchOrganizations(type, q)));
    }

    /** Jobs and degrees on someone's profile. Hidden entries only show to their owner. */
    @GetMapping("/users/{userId}/career")
    public ResponseEntity<ApiResponse<List<CareerEntryDto>>> list(@PathVariable UUID userId) {
        return ResponseEntity.ok(ApiResponse.success(
                careerService.list(SecurityUtils.currentUserId(), userId)));
    }

    @PostMapping("/career")
    public ResponseEntity<ApiResponse<CareerEntryDto>> create(@Valid @RequestBody SaveCareerRequest request) {
        return ResponseEntity.ok(ApiResponse.success(
                careerService.create(SecurityUtils.currentUserId(), request)));
    }

    @PutMapping("/career/{id}")
    public ResponseEntity<ApiResponse<CareerEntryDto>> update(
            @PathVariable UUID id, @Valid @RequestBody SaveCareerRequest request) {
        return ResponseEntity.ok(ApiResponse.success(
                careerService.update(SecurityUtils.currentUserId(), id, request)));
    }

    @DeleteMapping("/career/{id}")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable UUID id) {
        careerService.delete(SecurityUtils.currentUserId(), id);
        return ResponseEntity.ok(ApiResponse.success(null, "Entry deleted"));
    }
}