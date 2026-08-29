package com.apsconnect.api.common.util;

import com.apsconnect.api.common.exception.AppException;
import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class CursorSupportTest {

    @Test
    void encodeThenDecodeRoundTrips() {
        LocalDateTime ts = LocalDateTime.of(2026, 7, 5, 14, 30, 15, 123_000_000);
        String cursor = CursorSupport.encode(ts);
        assertThat(CursorSupport.decode(cursor)).isEqualTo(ts);
    }

    @Test
    void nullAndBlankDecodeToNull() {
        assertThat(CursorSupport.decode(null)).isNull();
        assertThat(CursorSupport.decode("")).isNull();
    }

    @Test
    void invalidCursorThrows() {
        assertThatThrownBy(() -> CursorSupport.decode("!!!not-base64!!!"))
                .isInstanceOf(AppException.class);
    }

    @Test
    void limitIsClampedToBounds() {
        assertThat(CursorSupport.clampLimit(0)).isEqualTo(CursorSupport.DEFAULT_LIMIT);
        assertThat(CursorSupport.clampLimit(-5)).isEqualTo(CursorSupport.DEFAULT_LIMIT);
        assertThat(CursorSupport.clampLimit(10)).isEqualTo(10);
        assertThat(CursorSupport.clampLimit(9999)).isEqualTo(CursorSupport.MAX_LIMIT);
    }
}
