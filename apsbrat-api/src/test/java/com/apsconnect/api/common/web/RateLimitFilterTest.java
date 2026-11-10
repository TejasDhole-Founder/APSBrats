package com.apsconnect.api.common.web;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.data.redis.RedisConnectionFailureException;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.startsWith;

class RateLimitFilterTest {

    private final StringRedisTemplate redis = Mockito.mock(StringRedisTemplate.class);
    @SuppressWarnings("unchecked")
    private final ValueOperations<String, String> values = Mockito.mock(ValueOperations.class);
    private final RateLimitFilter filter = new RateLimitFilter(redis, new ObjectMapper(), 3, 2);

    {
        Mockito.when(redis.opsForValue()).thenReturn(values);
    }

    @AfterEach
    void signOut() {
        SecurityContextHolder.clearContext();
    }

    private MockHttpServletResponse call(String path) throws Exception {
        MockHttpServletRequest req = new MockHttpServletRequest("GET", path);
        req.setRequestURI(path);
        req.setRemoteAddr("203.0.113.7");
        MockHttpServletResponse res = new MockHttpServletResponse();
        filter.doFilter(req, res, new MockFilterChain());
        return res;
    }

    @Test
    void signedInUserIsCountedByIdAndBlockedOverTheLimit() throws Exception {
        UUID userId = UUID.randomUUID();
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(userId, null, List.of()));
        Mockito.when(values.increment(startsWith("rl:u:" + userId))).thenReturn(3L, 4L);

        assertThat(call("/api/v1/feed/home").getStatus()).isEqualTo(200);
        MockHttpServletResponse blocked = call("/api/v1/feed/home");
        assertThat(blocked.getStatus()).isEqualTo(429);
        assertThat(blocked.getHeader("Retry-After")).isNotNull();
    }

    @Test
    void anonymousCallerIsCountedByIpWithTheLowerLimit() throws Exception {
        Mockito.when(values.increment(startsWith("rl:ip:203.0.113.7"))).thenReturn(3L);

        assertThat(call("/api/v1/schools").getStatus()).isEqualTo(429);
    }

    @Test
    void redisOutageLetsRequestsThrough() throws Exception {
        Mockito.when(values.increment(anyString())).thenThrow(new RedisConnectionFailureException("down"));

        assertThat(call("/api/v1/schools").getStatus()).isEqualTo(200);
    }

    @Test
    void mediaAndHealthAreNotCounted() throws Exception {
        call("/media/a.jpg");
        call("/actuator/health");

        Mockito.verifyNoInteractions(values);
    }
}
