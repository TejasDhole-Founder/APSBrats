package com.apsconnect.api.media;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.common.exception.ErrorCode;
import com.apsconnect.api.user.User;
import com.apsconnect.api.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AvatarService {

    private final UserRepository userRepository;
    private final StorageService storageService;
    private final ImageProcessor imageProcessor;

    @Transactional
    public String updateAvatar(UUID userId, MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new AppException("No file uploaded", HttpStatus.BAD_REQUEST, ErrorCode.BAD_REQUEST);
        }
        User user = userRepository.findById(userId)
                .filter(u -> u.getDeletedAt() == null)
                .orElseThrow(() -> new AppException("Account not found", HttpStatus.NOT_FOUND, ErrorCode.NOT_FOUND));

        byte[] raw;
        try {
            raw = file.getBytes();
        } catch (IOException ex) {
            throw new AppException("Could not read upload", HttpStatus.BAD_REQUEST, ErrorCode.BAD_REQUEST);
        }

        byte[] sanitized = imageProcessor.toSanitizedJpeg(raw, file.getContentType());
        String key = "avatars/" + userId + "-" + System.currentTimeMillis() + ".jpg";
        String url = storageService.store(key, sanitized, "image/jpeg");

        user.setProfilePicUrl(url);
        userRepository.save(user);
        return url;
    }
}
