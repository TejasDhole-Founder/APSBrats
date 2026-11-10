package com.apsconnect.api.media;

import com.apsconnect.api.common.exception.AppException;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThatThrownBy;

class R2StorageServiceTest {

    @Test
    void sdkFailureIsWrappedAsAppException() {
        // A syntactically valid but non-resolving host: the PUT fails at connection
        // time with an SdkException, proving store() doesn't leak that raw exception type.
        R2StorageService service = new R2StorageService(
                "account-that-does-not-exist", "key", "secret", "bucket", "https://media.apsbrats.com");

        assertThatThrownBy(() -> service.store("uploads/u1/f.jpg", "x".getBytes(), "image/jpeg"))
                .isInstanceOf(AppException.class);
    }
}
