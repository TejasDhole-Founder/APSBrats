package com.apsconnect.api.media;

import com.apsconnect.api.common.exception.AppException;
import org.springframework.http.HttpStatus;

import java.util.Locale;

/**
 * Which folder an upload goes under in storage — post, chat or event photo. Profile
 * photos aren't here: they go through {@link AvatarController} / {@link AvatarService}
 * instead, since an avatar replaces the user's one photo rather than attaching a new one.
 */
public enum UploadKind {
    POST, CHAT, EVENT;

    /** Storage folder name, e.g. "post". */
    public String folder() {
        return name().toLowerCase(Locale.ROOT);
    }

    public static UploadKind from(String raw) {
        try {
            return UploadKind.valueOf(raw == null ? "" : raw.toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException e) {
            throw new AppException("kind must be one of: post, chat, event", HttpStatus.BAD_REQUEST);
        }
    }
}
