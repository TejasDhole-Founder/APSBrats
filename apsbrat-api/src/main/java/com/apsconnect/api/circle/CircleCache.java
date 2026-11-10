package com.apsconnect.api.circle;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.Cursor;
import org.springframework.data.redis.core.ScanOptions;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Short-lived Redis cache for the people screen. Two things live here:
 * the ranked schoolmate id list (the expensive mutual-count pass) and the
 * summary counts. Every connection or school-history change for a user evicts
 * that user's keys. Redis being down never breaks a request — we just recompute.
 */
@Component
public class CircleCache {

    private static final Logger log = LoggerFactory.getLogger(CircleCache.class);
    static final Duration RANKING_TTL = Duration.ofMinutes(5);
    static final Duration SUMMARY_TTL = Duration.ofMinutes(2);

    private final StringRedisTemplate redis;

    public CircleCache(StringRedisTemplate redis) {
        this.redis = redis;
    }

    private static String prefix(UUID userId) {
        return "circle:" + userId + ":";
    }

    public Optional<List<UUID>> rankedIds(UUID userId, String scope) {
        try {
            String raw = redis.opsForValue().get(prefix(userId) + "rank:" + scope);
            if (raw == null) {
                return Optional.empty();
            }
            if (raw.isEmpty()) {
                return Optional.of(List.of());
            }
            return Optional.of(Arrays.stream(raw.split(",")).map(UUID::fromString).toList());
        } catch (RuntimeException e) {
            log.warn("circle cache read failed: {}", e.getMessage());
            return Optional.empty();
        }
    }

    public void putRankedIds(UUID userId, String scope, List<UUID> ids) {
        try {
            String raw = ids.stream().map(UUID::toString).collect(Collectors.joining(","));
            redis.opsForValue().set(prefix(userId) + "rank:" + scope, raw, RANKING_TTL);
        } catch (RuntimeException e) {
            log.warn("circle cache write failed: {}", e.getMessage());
        }
    }

    public Optional<String> summary(UUID userId) {
        try {
            return Optional.ofNullable(redis.opsForValue().get(prefix(userId) + "summary"));
        } catch (RuntimeException e) {
            return Optional.empty();
        }
    }

    public void putSummary(UUID userId, String json) {
        try {
            redis.opsForValue().set(prefix(userId) + "summary", json, SUMMARY_TTL);
        } catch (RuntimeException e) {
            log.warn("circle cache write failed: {}", e.getMessage());
        }
    }

    /**
     * Drop everything cached for this user (connections or schools changed).
     * SCAN, not KEYS: KEYS walks the whole keyspace in one blocking call.
     */
    public void evictUser(UUID userId) {
        try (Cursor<String> cursor = redis.scan(ScanOptions.scanOptions().match(prefix(userId) + "*").count(100).build())) {
            Set<String> keys = new HashSet<>();
            cursor.forEachRemaining(keys::add);
            if (!keys.isEmpty()) {
                redis.delete(keys);
            }
        } catch (RuntimeException e) {
            log.warn("circle cache evict failed: {}", e.getMessage());
        }
    }
}
