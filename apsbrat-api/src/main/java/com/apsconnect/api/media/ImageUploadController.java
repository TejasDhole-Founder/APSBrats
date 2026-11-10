package com.apsconnect.api.media;

import com.apsconnect.api.common.response.ApiResponse;
import com.apsconnect.api.common.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/media")
@RequiredArgsConstructor
public class ImageUploadController {

    private final ImageUploadService imageUploadService;

    /**
     * {@code kind} is post, chat or event — it decides which folder the photo is
     * grouped under in storage. Returns {"url": "https://.../{kind}/<me>/<id>.jpg"}
     * to attach to a post, message or event.
     */
    @PostMapping(value = "/images", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<Map<String, String>>> upload(
            @RequestParam("file") MultipartFile file, @RequestParam("kind") String kind) {
        String url = imageUploadService.upload(SecurityUtils.currentUserId(), file, UploadKind.from(kind));
        return ResponseEntity.ok(ApiResponse.success(Map.of("url", url)));
    }
}
