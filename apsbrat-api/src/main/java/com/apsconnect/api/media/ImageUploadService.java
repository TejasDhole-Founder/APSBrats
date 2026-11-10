package com.apsconnect.api.media;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.common.exception.ErrorCode;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.time.Duration;
import java.util.UUID;
import java.util.regex.Pattern;

/**
 * Photos for posts, chat and events. Upload first (POST /media/images?kind=...), then
 * attach the returned address to a post, message or event. Every upload is re-encoded
 * (location data stripped) and stored under {@code {kind}/{userId}/{uuid}.jpg} — grouped
 * by what it's for, which is also how {@link #requireOwnUpload} knows who it belongs to.
 * Profile photos are separate: see {@link AvatarService}.
 */
@Service
@RequiredArgsConstructor
public class ImageUploadService {

    /** Long side of a post or chat photo, in pixels. Sharp on phones, small to download. */
    private static final int PHOTO_MAX_DIMENSION = 1600;
    private static final int MAX_UPLOADS_PER_HOUR = 30;

    private final StorageService storageService;
    private final ImageProcessor imageProcessor;
    private final StringRedisTemplate redis;

    @Value("${app.media.base-url:/media}")
    String mediaBaseUrl; // package-private: set directly in tests, where Spring isn't injecting it

    public String upload(UUID userId, MultipartFile file, UploadKind kind) {
        if (file == null || file.isEmpty()) {
            throw new AppException("No file uploaded", HttpStatus.BAD_REQUEST, ErrorCode.BAD_REQUEST);
        }
        rateLimit(userId);
        byte[] raw;
        try {
            raw = file.getBytes();
        } catch (IOException ex) {
            throw new AppException("Could not read upload", HttpStatus.BAD_REQUEST, ErrorCode.BAD_REQUEST);
        }
        byte[] jpeg = imageProcessor.toSanitizedJpeg(raw, file.getContentType(), PHOTO_MAX_DIMENSION);
        String key = kind.folder() + "/" + userId + "/" + UUID.randomUUID() + ".jpg";
        return storageService.store(key, jpeg, "image/jpeg");
    }

    /**
     * The photo to attach, or null when none was given. Only addresses this
     * person uploaded are accepted: no outside links, no one else's photos.
     */
    public String requireOwnUpload(UUID userId, String imageUrl) {
        if (imageUrl == null || imageUrl.isBlank()) {
            return null;
        }
        String base = mediaBaseUrl.endsWith("/") ? mediaBaseUrl.substring(0, mediaBaseUrl.length() - 1) : mediaBaseUrl;
        Pattern own = Pattern.compile(Pattern.quote(base + "/") + "(post|chat|event)/"
                + Pattern.quote(userId.toString()) + "/[0-9a-f-]{36}\\.jpg");
        if (!own.matcher(imageUrl.trim()).matches()) {
            throw new AppException("That photo can't be attached. Upload it again.", HttpStatus.BAD_REQUEST);
        }
        return imageUrl.trim();
    }

    private void rateLimit(UUID userId) {
        String key = "ratelimit:uploads:" + userId;
        Long count = redis.opsForValue().increment(key);
        if (count != null && count == 1L) {
            redis.expire(key, Duration.ofHours(1));
        }
        if (count != null && count > MAX_UPLOADS_PER_HOUR) {
            throw new AppException("You've uploaded a lot of photos. Try again in a little while.",
                    HttpStatus.TOO_MANY_REQUESTS, ErrorCode.RATE_LIMITED);
        }
    }
}
