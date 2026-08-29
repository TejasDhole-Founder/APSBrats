package com.apsconnect.api.common.util;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.common.exception.ErrorCode;
import org.springframework.http.HttpStatus;

import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.Base64;

public final class CursorSupport {

    public static final int DEFAULT_LIMIT = 30;
    public static final int MAX_LIMIT = 100;

    private CursorSupport() {
    }

    public static int clampLimit(int limit) {
        if (limit <= 0) {
            return DEFAULT_LIMIT;
        }
        return Math.min(limit, MAX_LIMIT);
    }

    public static String encode(LocalDateTime timestamp) {
        if (timestamp == null) {
            return null;
        }
        return Base64.getUrlEncoder().withoutPadding()
                .encodeToString(timestamp.toString().getBytes(StandardCharsets.UTF_8));
    }

    public static LocalDateTime decode(String cursor) {
        if (cursor == null || cursor.isBlank()) {
            return null;
        }
        try {
            String raw = new String(Base64.getUrlDecoder().decode(cursor), StandardCharsets.UTF_8);
            return LocalDateTime.parse(raw);
        } catch (RuntimeException ex) {
            throw new AppException("Invalid cursor", HttpStatus.BAD_REQUEST, ErrorCode.BAD_REQUEST);
        }
    }
}
