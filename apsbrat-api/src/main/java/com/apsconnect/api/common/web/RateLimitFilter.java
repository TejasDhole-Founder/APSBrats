package com.apsconnect.api.common.web;

import com.apsconnect.api.common.exception.ErrorCode;
import com.apsconnect.api.common.response.ApiResponse;
import com.apsconnect.api.common.security.SecurityUtils;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.slf4j.MDC;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.dao.DataAccessException;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.lang.NonNull;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.UUID;

/**
 * A request budget per minute for every API call: per signed-in user, or per client IP
 * before sign-in. Sits on top of the per-action limits (OTP, posts, chat, uploads).
 * Runs after Spring Security so the caller is known, and before IdempotencyFilter.
 * The client IP is getRemoteAddr(), which Tomcat's RemoteIpValve (server.forward-headers-strategy)
 * fills from X-Forwarded-For only when the hop is a trusted proxy, so it can't be spoofed.
 */
@Slf4j
@Component
@Order(Ordered.LOWEST_PRECEDENCE - 10)
public class RateLimitFilter extends OncePerRequestFilter {

    private final StringRedisTemplate redis;
    private final ObjectMapper mapper;
    private final int userPerMinute;
    private final int ipPerMinute;

    public RateLimitFilter(StringRedisTemplate redis, ObjectMapper mapper,
                           @Value("${app.rate-limit.user-per-minute:300}") int userPerMinute,
                           @Value("${app.rate-limit.ip-per-minute:60}") int ipPerMinute) {
        this.redis = redis;
        this.mapper = mapper;
        this.userPerMinute = userPerMinute;
        this.ipPerMinute = ipPerMinute;
    }

    @Override
    protected boolean shouldNotFilter(@NonNull HttpServletRequest req) {
        String path = req.getRequestURI();
        return "OPTIONS".equals(req.getMethod())
                || path.startsWith("/actuator/")
                || path.startsWith("/ws")
                || path.startsWith("/media/");
    }

    @Override
    protected void doFilterInternal(@NonNull HttpServletRequest req,
                                    @NonNull HttpServletResponse res,
                                    @NonNull FilterChain chain) throws ServletException, IOException {
        UUID userId = SecurityUtils.currentUserIdOrNull();
        String who = userId != null ? "u:" + userId : "ip:" + req.getRemoteAddr();
        int limit = userId != null ? userPerMinute : ipPerMinute;
        long minute = System.currentTimeMillis() / 60_000;
        String key = "rl:" + who + ":" + minute;

        Long count;
        try {
            count = redis.opsForValue().increment(key);
            if (count != null && count == 1L) {
                redis.expire(key, Duration.ofSeconds(90));
            }
        } catch (DataAccessException e) {
            // Fail open: a Redis outage shouldn't take every endpoint down with it.
            log.warn("Rate limit check skipped, Redis unavailable: {}", e.getMessage());
            count = null;
        }

        if (count != null && count > limit) {
            long secondsLeft = 60 - (System.currentTimeMillis() / 1000) % 60;
            res.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
            res.setHeader("Retry-After", String.valueOf(secondsLeft));
            res.setContentType(MediaType.APPLICATION_JSON_VALUE);
            res.setCharacterEncoding(StandardCharsets.UTF_8.name());
            res.getWriter().write(mapper.writeValueAsString(ApiResponse.error(
                    "Too many requests. Please wait a moment and try again.",
                    ErrorCode.RATE_LIMITED.name(), MDC.get(RequestIdFilter.MDC_KEY))));
            return;
        }
        chain.doFilter(req, res);
    }
}
