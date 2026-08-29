package com.apsconnect.api.media;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.common.exception.ErrorCode;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

/**
 * Dev/default storage backing. In prod this is swapped for an S3/GCS-backed
 * implementation (behind a CDN with signed URLs) via the {@link StorageService}
 * interface — no caller changes required.
 */
@Service
public class LocalStorageService implements StorageService {

    private final Path root;
    private final String baseUrl;

    public LocalStorageService(
            @Value("${app.media.dir:./media}") String dir,
            @Value("${app.media.base-url:/media}") String baseUrl) {
        this.root = Paths.get(dir).toAbsolutePath().normalize();
        this.baseUrl = baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length() - 1) : baseUrl;
    }

    @Override
    public String store(String key, byte[] content, String contentType) {
        try {
            Path target = root.resolve(key).normalize();
            if (!target.startsWith(root)) {
                throw new AppException("Invalid storage key", HttpStatus.BAD_REQUEST, ErrorCode.BAD_REQUEST);
            }
            Files.createDirectories(target.getParent());
            Files.write(target, content);
            return baseUrl + "/" + key;
        } catch (IOException ex) {
            throw new AppException("Could not store file", HttpStatus.INTERNAL_SERVER_ERROR, ErrorCode.INTERNAL_ERROR);
        }
    }
}
