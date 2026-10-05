package com.meeplehearth.config;

import com.meeplehearth.common.ratelimit.RedisRateLimiter;
import jakarta.servlet.FilterChain;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.AnonymousAuthenticationToken;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.AuthorityUtils;
import org.springframework.security.core.context.SecurityContextHolder;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class GlobalRateLimitFilterFeatureTest {

    /** 12:00:45 UTC: 15 seconds left in the window. */
    private static final Instant NOW = Instant.parse("2026-10-05T12:00:45Z");
    private static final long WINDOW = NOW.getEpochSecond() / 60;

    private final RedisRateLimiter limiter = mock(RedisRateLimiter.class);
    private final AppProperties.RateLimit limits = new AppProperties.RateLimit();
    private final GlobalRateLimitFilter filter =
            new GlobalRateLimitFilter(limiter, limits, Clock.fixed(NOW, ZoneOffset.UTC));
    private final FilterChain chain = mock(FilterChain.class);

    @AfterEach
    void clearContext() {
        SecurityContextHolder.clearContext();
    }

    private static MockHttpServletRequest request(String method, String path) {
        MockHttpServletRequest request = new MockHttpServletRequest(method, path);
        request.setRemoteAddr("203.0.113.9");
        return request;
    }

    private MockHttpServletResponse run(MockHttpServletRequest request) throws Exception {
        MockHttpServletResponse response = new MockHttpServletResponse();
        filter.doFilter(request, response, chain);
        return response;
    }

    @Test
    void authenticatedRequestsCountPerUser() throws Exception {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(
                "user-1", null, AuthorityUtils.createAuthorityList("ROLE_USER")));
        when(limiter.increment(anyString(), any(Duration.class))).thenReturn(200L);

        MockHttpServletResponse response = run(request("GET", "/api/v1/feed"));

        verify(limiter).increment(eq("ratelimit:global:user:user-1:" + WINDOW), any(Duration.class));
        verify(chain).doFilter(any(), any());
        assertThat(response.getHeader("X-RateLimit-Limit")).isEqualTo("200");
        assertThat(response.getHeader("X-RateLimit-Remaining")).isEqualTo("0");
    }

    @Test
    void overTheLimitAnswers429WithRetryAfter() throws Exception {
        when(limiter.increment(anyString(), any(Duration.class))).thenReturn(21L);

        MockHttpServletResponse response = run(request("GET", "/api/v1/auth/check-username"));

        verify(limiter).increment(eq("ratelimit:global:ip:203.0.113.9:" + WINDOW), any(Duration.class));
        verify(chain, never()).doFilter(any(), any());
        assertThat(response.getStatus()).isEqualTo(429);
        assertThat(response.getHeader("Retry-After")).isEqualTo("15");
        assertThat(response.getContentAsString()).contains("\"code\":\"RATE_LIMIT_EXCEEDED\"");
    }

    @Test
    void loginAndReactivateUseTheStricterBucket() throws Exception {
        SecurityContextHolder.getContext().setAuthentication(new AnonymousAuthenticationToken(
                "key", "anonymousUser", AuthorityUtils.createAuthorityList("ROLE_ANONYMOUS")));
        when(limiter.increment(anyString(), any(Duration.class))).thenReturn(11L);

        assertThat(run(request("POST", "/api/v1/auth/login/")).getStatus()).isEqualTo(429);
        assertThat(run(request("POST", "/api/v1/auth/reactivate")).getStatus()).isEqualTo(429);
        verify(limiter, org.mockito.Mockito.times(2))
                .increment(eq("ratelimit:global:login:203.0.113.9:" + WINDOW), any(Duration.class));
    }

    @Test
    void refreshIsExemptFromThePerIpLimitAndNonApiPathsAreIgnored() throws Exception {
        run(request("POST", "/api/v1/auth/refresh"));
        run(request("GET", "/.well-known/assetlinks.json"));
        run(request("OPTIONS", "/api/v1/feed"));
        verifyNoInteractions(limiter);
        verify(chain, org.mockito.Mockito.times(3)).doFilter(any(), any());
    }

    @Test
    void redisFailureLetsTheRequestThrough() throws Exception {
        when(limiter.increment(anyString(), any(Duration.class))).thenThrow(new IllegalStateException("down"));
        MockHttpServletResponse response = run(request("GET", "/api/v1/games"));
        assertThat(response.getStatus()).isEqualTo(200);
        verify(chain).doFilter(any(), any());
    }

    @Test
    void disabledFilterDoesNothing() throws Exception {
        limits.setEnabled(false);
        run(request("GET", "/api/v1/games"));
        verifyNoInteractions(limiter);
        verify(chain).doFilter(any(), any());
    }
}
