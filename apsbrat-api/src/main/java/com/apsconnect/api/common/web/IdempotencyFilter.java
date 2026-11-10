package com.apsconnect.api.common.web;

import com.apsconnect.api.common.exception.ErrorCode;
import com.apsconnect.api.common.response.ApiResponse;
import com.apsconnect.api.common.security.SecurityUtils;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.slf4j.MDC;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.lang.NonNull;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.web.util.ContentCachingResponseWrapper;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.UUID;

/**
 * A POST carrying an Idempotency-Key runs once per signed-in user; a retry with the
 * same key gets the stored 2xx response back instead of creating a duplicate.
 * Runs after Spring Security (default order), so the caller is already known.
 */
@Component
@Order(Ordered.LOWEST_PRECEDENCE)
@RequiredArgsConstructor
public class IdempotencyFilter extends OncePerRequestFilter {

    public static final String HEADER = "Idempotency-Key";
    public static final String REPLAYED_HEADER = "Idempotent-Replayed";
    private static final String PENDING = "pending";
    private static final Duration PENDING_TTL = Duration.ofSeconds(60);
    private static final Duration RESULT_TTL = Duration.ofHours(24);
    private static final int MAX_KEY_LENGTH = 100;

    private final StringRedisTemplate redis;
    private final ObjectMapper mapper;

    record Stored(int status, String contentType, String body) {
    }

    @Override
    protected boolean shouldNotFilter(@NonNull HttpServletRequest req) {
        String key = req.getHeader(HEADER);
        return !"POST".equals(req.getMethod()) || key == null || key.isBlank() || key.length() > MAX_KEY_LENGTH;
    }

    @Override
    protected void doFilterInternal(@NonNull HttpServletRequest req,
                                    @NonNull HttpServletResponse res,
                                    @NonNull FilterChain chain) throws ServletException, IOException {
        UUID userId = SecurityUtils.currentUserIdOrNull();
        if (userId == null) {
            chain.doFilter(req, res);
            return;
        }
        String key = "idem:" + userId + ":" + req.getRequestURI() + ":" + req.getHeader(HEADER);

        if (!Boolean.TRUE.equals(redis.opsForValue().setIfAbsent(key, PENDING, PENDING_TTL))) {
            String stored = redis.opsForValue().get(key);
            if (stored == null || PENDING.equals(stored)) {
                writeInProgress(res);
            } else {
                replay(res, mapper.readValue(stored, Stored.class));
            }
            return;
        }

        ContentCachingResponseWrapper wrapped = new ContentCachingResponseWrapper(res);
        boolean saved = false;
        try {
            chain.doFilter(req, wrapped);
            int status = wrapped.getStatus();
            // Only successes are remembered: a failed attempt must stay retryable.
            if (status >= 200 && status < 300) {
                String body = new String(wrapped.getContentAsByteArray(), StandardCharsets.UTF_8);
                redis.opsForValue().set(key,
                        mapper.writeValueAsString(new Stored(status, wrapped.getContentType(), body)), RESULT_TTL);
                saved = true;
            }
        } finally {
            if (!saved) {
                redis.delete(key);
            }
            wrapped.copyBodyToResponse();
        }
    }

    private void replay(HttpServletResponse res, Stored stored) throws IOException {
        res.setStatus(stored.status());
        if (stored.contentType() != null) {
            res.setContentType(stored.contentType());
        }
        res.setHeader(REPLAYED_HEADER, "true");
        res.getOutputStream().write(stored.body().getBytes(StandardCharsets.UTF_8));
    }

    private void writeInProgress(HttpServletResponse res) throws IOException {
        res.setStatus(HttpStatus.CONFLICT.value());
        res.setContentType(MediaType.APPLICATION_JSON_VALUE);
        res.setCharacterEncoding(StandardCharsets.UTF_8.name());
        ApiResponse<Void> body = ApiResponse.error(
                "This request is already being processed", ErrorCode.CONFLICT.name(), MDC.get(RequestIdFilter.MDC_KEY));
        res.getWriter().write(mapper.writeValueAsString(body));
    }
}
