package com.apsconnect.api.common.web;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.time.Duration;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;

class IdempotencyFilterTest {

    private final StringRedisTemplate redis = Mockito.mock(StringRedisTemplate.class);
    @SuppressWarnings("unchecked")
    private final ValueOperations<String, String> values = Mockito.mock(ValueOperations.class);
    private final ObjectMapper mapper = new ObjectMapper();
    private final IdempotencyFilter filter = new IdempotencyFilter(redis, mapper);
    private final UUID userId = UUID.randomUUID();
    private final AtomicInteger handlerCalls = new AtomicInteger();

    @BeforeEach
    void signIn() {
        Mockito.when(redis.opsForValue()).thenReturn(values);
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(userId, null, List.of()));
    }

    @AfterEach
    void signOut() {
        SecurityContextHolder.clearContext();
    }

    private MockHttpServletRequest post(String key) {
        MockHttpServletRequest req = new MockHttpServletRequest("POST", "/api/v1/communities/c1/posts");
        req.setRequestURI("/api/v1/communities/c1/posts");
        if (key != null) {
            req.addHeader(IdempotencyFilter.HEADER, key);
        }
        return req;
    }

    private MockFilterChain chainReturning(int status, String body) {
        return new MockFilterChain(new HttpServlet() {
            @Override
            protected void service(HttpServletRequest req, HttpServletResponse res) throws java.io.IOException {
                handlerCalls.incrementAndGet();
                res.setStatus(status);
                res.setContentType("application/json");
                res.getWriter().write(body);
            }
        });
    }

    @Test
    void firstRequestRunsAndStoresTheSuccess() throws Exception {
        Mockito.when(values.setIfAbsent(anyString(), eq("pending"), any(Duration.class))).thenReturn(true);
        MockHttpServletResponse res = new MockHttpServletResponse();

        filter.doFilter(post("k1"), res, chainReturning(201, "{\"id\":\"p1\"}"));

        assertThat(handlerCalls).hasValue(1);
        assertThat(res.getStatus()).isEqualTo(201);
        assertThat(res.getContentAsString()).isEqualTo("{\"id\":\"p1\"}");
        Mockito.verify(values).set(eq("idem:" + userId + ":/api/v1/communities/c1/posts:k1"),
                Mockito.contains("p1"), eq(Duration.ofHours(24)));
    }

    @Test
    void retryWithSameKeyReplaysWithoutRunningAgain() throws Exception {
        Mockito.when(values.setIfAbsent(anyString(), eq("pending"), any(Duration.class))).thenReturn(false);
        Mockito.when(values.get(anyString())).thenReturn(mapper.writeValueAsString(
                new IdempotencyFilter.Stored(201, "application/json", "{\"id\":\"p1\"}")));
        MockHttpServletResponse res = new MockHttpServletResponse();

        filter.doFilter(post("k1"), res, chainReturning(201, "{\"id\":\"p2\"}"));

        assertThat(handlerCalls).hasValue(0);
        assertThat(res.getStatus()).isEqualTo(201);
        assertThat(res.getContentAsString()).isEqualTo("{\"id\":\"p1\"}");
        assertThat(res.getHeader(IdempotencyFilter.REPLAYED_HEADER)).isEqualTo("true");
    }

    @Test
    void concurrentDuplicateGets409() throws Exception {
        Mockito.when(values.setIfAbsent(anyString(), eq("pending"), any(Duration.class))).thenReturn(false);
        Mockito.when(values.get(anyString())).thenReturn("pending");
        MockHttpServletResponse res = new MockHttpServletResponse();

        filter.doFilter(post("k1"), res, chainReturning(201, "{}"));

        assertThat(handlerCalls).hasValue(0);
        assertThat(res.getStatus()).isEqualTo(409);
    }

    @Test
    void failureIsForgottenSoTheRetryCanRun() throws Exception {
        Mockito.when(values.setIfAbsent(anyString(), eq("pending"), any(Duration.class))).thenReturn(true);

        filter.doFilter(post("k1"), new MockHttpServletResponse(), chainReturning(400, "{}"));

        Mockito.verify(redis).delete("idem:" + userId + ":/api/v1/communities/c1/posts:k1");
        Mockito.verify(values, Mockito.never()).set(anyString(), anyString(), any(Duration.class));
    }

    @Test
    void postWithoutKeyPassesStraightThrough() throws Exception {
        filter.doFilter(post(null), new MockHttpServletResponse(), chainReturning(201, "{}"));

        assertThat(handlerCalls).hasValue(1);
        Mockito.verifyNoInteractions(values);
    }
}
