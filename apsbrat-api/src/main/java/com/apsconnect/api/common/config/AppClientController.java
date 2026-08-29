package com.apsconnect.api.common.config;

import com.apsconnect.api.common.response.ApiResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * Server-driven client gate. The app calls this on launch to learn the minimum
 * supported build (force-update) and whether the API is in maintenance.
 */
@RestController
@RequestMapping("/api/v1/app")
public class AppClientController {

    @Value("${app.client.min-supported-build:1}")
    private int minSupportedBuild;

    @Value("${app.client.latest-build:1}")
    private int latestBuild;

    @Value("${app.client.maintenance:false}")
    private boolean maintenance;

    @Value("${app.client.message:}")
    private String message;

    @GetMapping("/config")
    public ResponseEntity<ApiResponse<Map<String, Object>>> config() {
        return ResponseEntity.ok(ApiResponse.success(Map.of(
                "minSupportedBuild", minSupportedBuild,
                "latestBuild", latestBuild,
                "maintenance", maintenance,
                "message", message == null ? "" : message
        )));
    }
}
