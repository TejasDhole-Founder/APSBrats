package com.apsconnect.api.media;

import com.apsconnect.api.common.exception.AppException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.mock.web.MockMultipartFile;

import java.time.Duration;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;

class ImageUploadServiceTest {

    private final StorageService storage = Mockito.mock(StorageService.class);
    private final ImageProcessor imageProcessor = Mockito.mock(ImageProcessor.class);
    private final StringRedisTemplate redis = Mockito.mock(StringRedisTemplate.class);
    @SuppressWarnings("unchecked")
    private final ValueOperations<String, String> values = Mockito.mock(ValueOperations.class);
    private final ImageUploadService service = new ImageUploadService(storage, imageProcessor, redis);
    private final UUID userId = UUID.randomUUID();

    @BeforeEach
    void stubCollaborators() {
        service.mediaBaseUrl = "https://media.apsbrats.com";
        Mockito.when(redis.opsForValue()).thenReturn(values);
        Mockito.when(values.increment(anyString())).thenReturn(1L);
        Mockito.when(imageProcessor.toSanitizedJpeg(any(), any(), eq(1600))).thenReturn("jpeg".getBytes());
        Mockito.when(storage.store(anyString(), any(), eq("image/jpeg")))
                .thenAnswer(inv -> "https://media.apsbrats.com/" + inv.getArgument(0, String.class));
    }

    private MockMultipartFile aPhoto() {
        return new MockMultipartFile("file", "a.jpg", "image/jpeg", new byte[] {1, 2, 3});
    }

    @Test
    void uploadGroupsByKindAndUser() {
        String url = service.upload(userId, aPhoto(), UploadKind.POST);

        assertThat(url).matches("https://media\\.apsbrats\\.com/post/" + userId + "/[0-9a-f-]{36}\\.jpg");
    }

    @Test
    void differentKindsGoInDifferentFolders() {
        assertThat(service.upload(userId, aPhoto(), UploadKind.CHAT)).contains("/chat/" + userId + "/");
        assertThat(service.upload(userId, aPhoto(), UploadKind.EVENT)).contains("/event/" + userId + "/");
    }

    @Test
    void requireOwnUploadAcceptsAFreshUploadOfAnyKind() {
        String url = service.upload(userId, aPhoto(), UploadKind.POST);

        assertThat(service.requireOwnUpload(userId, url)).isEqualTo(url);
    }

    @Test
    void requireOwnUploadRejectsSomeoneElsesPhoto() {
        String someoneElse = service.upload(UUID.randomUUID(), aPhoto(), UploadKind.POST);

        assertThatThrownBy(() -> service.requireOwnUpload(userId, someoneElse))
                .isInstanceOf(AppException.class);
    }

    @Test
    void requireOwnUploadRejectsTheOldUngroupedFormat() {
        String legacy = "https://media.apsbrats.com/uploads/" + userId + "/" + UUID.randomUUID() + ".jpg";

        assertThatThrownBy(() -> service.requireOwnUpload(userId, legacy))
                .isInstanceOf(AppException.class);
    }

    @Test
    void uploadKindRejectsAnythingNotPostChatOrEvent() {
        assertThatThrownBy(() -> UploadKind.from("profile")).isInstanceOf(AppException.class);
        assertThatThrownBy(() -> UploadKind.from(null)).isInstanceOf(AppException.class);
        assertThat(UploadKind.from("post")).isEqualTo(UploadKind.POST);
        assertThat(UploadKind.from("CHAT")).isEqualTo(UploadKind.CHAT);
    }
}
