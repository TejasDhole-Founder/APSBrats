package com.apsconnect.api.media;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.common.exception.ErrorCode;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import javax.imageio.ImageIO;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Set;

/**
 * Decodes an uploaded image and re-encodes it to a clean JPEG. Re-encoding via
 * ImageIO drops all embedded metadata (EXIF/GPS) — critical OPSEC hygiene for
 * military-family users — and normalises size/format before serving.
 */
@Component
public class ImageProcessor {

    private static final Set<String> ALLOWED_TYPES = Set.of("image/jpeg", "image/jpg", "image/png");
    private static final long MAX_BYTES = 5L * 1024 * 1024;
    private static final int MAX_DIMENSION = 1024;

    public byte[] toSanitizedJpeg(byte[] input, String contentType) {
        if (input == null || input.length == 0) {
            throw bad("Empty file");
        }
        if (input.length > MAX_BYTES) {
            throw new AppException("Image must be 5MB or smaller",
                    HttpStatus.PAYLOAD_TOO_LARGE, ErrorCode.PAYLOAD_TOO_LARGE);
        }
        if (contentType == null || !ALLOWED_TYPES.contains(contentType.toLowerCase())) {
            throw new AppException("Only JPEG or PNG images are allowed",
                    HttpStatus.UNSUPPORTED_MEDIA_TYPE, ErrorCode.UNSUPPORTED_MEDIA_TYPE);
        }

        BufferedImage source;
        try {
            source = ImageIO.read(new ByteArrayInputStream(input));
        } catch (IOException ex) {
            throw bad("Could not read image");
        }
        if (source == null) {
            throw bad("Unsupported or corrupt image");
        }

        BufferedImage scaled = scaleWithinBounds(source);
        BufferedImage rgb = new BufferedImage(scaled.getWidth(), scaled.getHeight(), BufferedImage.TYPE_INT_RGB);
        Graphics2D g = rgb.createGraphics();
        g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BILINEAR);
        g.drawImage(scaled, 0, 0, null);
        g.dispose();

        try {
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            if (!ImageIO.write(rgb, "jpg", out)) {
                throw bad("Could not encode image");
            }
            return out.toByteArray();
        } catch (IOException ex) {
            throw bad("Could not encode image");
        }
    }

    private BufferedImage scaleWithinBounds(BufferedImage source) {
        int w = source.getWidth();
        int h = source.getHeight();
        if (w <= MAX_DIMENSION && h <= MAX_DIMENSION) {
            return source;
        }
        double scale = Math.min((double) MAX_DIMENSION / w, (double) MAX_DIMENSION / h);
        int nw = Math.max(1, (int) Math.round(w * scale));
        int nh = Math.max(1, (int) Math.round(h * scale));
        BufferedImage resized = new BufferedImage(nw, nh, BufferedImage.TYPE_INT_ARGB);
        Graphics2D g = resized.createGraphics();
        g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BILINEAR);
        g.drawImage(source, 0, 0, nw, nh, null);
        g.dispose();
        return resized;
    }

    private AppException bad(String message) {
        return new AppException(message, HttpStatus.BAD_REQUEST, ErrorCode.BAD_REQUEST);
    }
}
