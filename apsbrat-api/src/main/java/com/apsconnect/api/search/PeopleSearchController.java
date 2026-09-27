package com.apsconnect.api.search;

import com.apsconnect.api.common.response.ApiResponse;
import com.apsconnect.api.common.security.SecurityUtils;
import com.apsconnect.api.user.PersonDto;
import com.apsconnect.api.user.UserStatus;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import com.apsconnect.api.user.history.Stream;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/people/search")
@RequiredArgsConstructor
public class PeopleSearchController {

    private final PeopleSearchService peopleSearchService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<PersonDto>>> search(
            @RequestParam(defaultValue = "") String q,
            @RequestParam(required = false) UUID schoolId,
            @RequestParam(required = false) Short batch,
            @RequestParam(required = false) Short classTo,
            @RequestParam(required = false) String section,
            @RequestParam(required = false) Stream stream,
            @RequestParam(required = false) UserStatus status,
            @RequestParam(required = false) String city,
            @RequestParam(defaultValue = "false") boolean mine,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "" + PeopleSearchService.DEFAULT_PAGE_SIZE) int size) {
        var filters = new PeopleSearchService.Filters(
                schoolId, batch, classTo, blankToNull(section), stream, status, blankToNull(city));
        return ResponseEntity.ok(ApiResponse.success(
                peopleSearchService.search(SecurityUtils.currentUserId(), q, filters, mine, page, size)));
    }

    private static String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }
}
