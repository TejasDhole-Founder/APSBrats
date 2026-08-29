package com.apsconnect.api.media;

import com.apsconnect.api.common.exception.AppException;
import org.junit.jupiter.api.Test;

import javax.imageio.ImageIO;
import java.awt.Color;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class ImageProcessorTest {

    private final ImageProcessor processor = new ImageProcessor();

    private byte[] samplePng() throws IOException {
        BufferedImage img = new BufferedImage(20, 20, BufferedImage.TYPE_INT_RGB);
        var g = img.createGraphics();
        g.setColor(Color.RED);
        g.fillRect(0, 0, 20, 20);
        g.dispose();
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        ImageIO.write(img, "png", out);
        return out.toByteArray();
    }

    @Test
    void reencodesValidPngToJpeg() throws IOException {
        byte[] result = processor.toSanitizedJpeg(samplePng(), "image/png");
        assertThat(result).isNotEmpty();
        BufferedImage decoded = ImageIO.read(new ByteArrayInputStream(result));
        assertThat(decoded).isNotNull();
        assertThat(decoded.getWidth()).isEqualTo(20);
    }

    @Test
    void rejectsUnsupportedContentType() throws IOException {
        assertThatThrownBy(() -> processor.toSanitizedJpeg(samplePng(), "application/pdf"))
                .isInstanceOf(AppException.class);
    }

    @Test
    void rejectsCorruptImageBytes() {
        assertThatThrownBy(() -> processor.toSanitizedJpeg(new byte[]{1, 2, 3, 4}, "image/png"))
                .isInstanceOf(AppException.class);
    }
}
