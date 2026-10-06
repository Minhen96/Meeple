package com.meeplehearth.config;

import com.meeplehearth.common.ratelimit.RedisRateLimiter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.AnonymousAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.web.util.UrlPathHelper;

import java.io.IOException;
import java.time.Clock;
import java.time.Duration;
import java.util.Locale;
import java.util.Set;

/**
 * Global API rate limits (FEATURES_COMPLETE section 12.6), fixed one-minute windows in Redis:
 * <ul>
 *   <li>login and account reactivation: {@code loginPerMinute} per client IP, signed in or not;</li>
 *   <li>username / email availability checks (typed into the sign-up form):
 *       {@code availabilityPerMinute} per client IP, in their own bucket;</li>
 *   <li>authenticated requests: {@code perUserPerMinute} per user;</li>
 *   <li>other unauthenticated requests: {@code perIpPerMinute} per client IP.</li>
 * </ul>
 * Buckets are chosen on the decoded, normalised path (percent-decoding, {@code ;params}
 * stripped, duplicate and trailing slashes removed, lower case), so {@code /api/v1/auth/l%6Fgin}
 * counts as login, exactly like the handler mapping that serves it.
 * Over the limit the request is answered 429 {@code RATE_LIMIT_EXCEEDED} with a
 * {@code Retry-After} header (seconds until the window resets). Runs after the JWT filter so the
 * user is known; the client IP comes from {@code getRemoteAddr()}, which Tomcat's RemoteIpValve
 * resolves from trusted proxies only. If Redis is unreachable the request is let through: rate
 * limiting must never take the API down.
 *
 * <p>Token refresh and logout are exempt from the per-IP limit: server-side rendering refreshes
 * sessions for many users from a few edge IPs, and refresh tokens cannot be guessed.
 */
public class GlobalRateLimitFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(GlobalRateLimitFilter.class);
    static final String KEY_PREFIX = "ratelimit:global:";
    private static final Duration KEY_TTL = Duration.ofMinutes(2);
    private static final Set<String> LOGIN_PATHS = Set.of("/api/v1/auth/login", "/api/v1/auth/reactivate");
    private static final Set<String> IP_EXEMPT_PATHS = Set.of("/api/v1/auth/refresh", "/api/v1/auth/logout");
    private static final Set<String> AVAILABILITY_PATHS =
            Set.of("/api/v1/auth/check-username", "/api/v1/auth/check-email");

    private final RedisRateLimiter rateLimiter;
    private final AppProperties.RateLimit limits;
    private final Clock clock;

    public GlobalRateLimitFilter(RedisRateLimiter rateLimiter, AppProperties.RateLimit limits) {
        this(rateLimiter, limits, Clock.systemUTC());
    }

    GlobalRateLimitFilter(RedisRateLimiter rateLimiter, AppProperties.RateLimit limits, Clock clock) {
        this.rateLimiter = rateLimiter;
        this.limits = limits;
        this.clock = clock;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !limits.isEnabled()
                || "OPTIONS".equalsIgnoreCase(request.getMethod())
                || !path(request).startsWith("/api/");
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        String path = path(request);
        long epochSecond = clock.instant().getEpochSecond();
        long window = epochSecond / 60;
        long retryAfter = 60 - (epochSecond % 60);

        String key;
        long limit;
        if (LOGIN_PATHS.contains(path) && "POST".equalsIgnoreCase(request.getMethod())) {
            key = KEY_PREFIX + "login:" + clientIp(request) + ":" + window;
            limit = limits.getLoginPerMinute();
        } else if (AVAILABILITY_PATHS.contains(path)) {
            key = KEY_PREFIX + "availability:" + clientIp(request) + ":" + window;
            limit = limits.getAvailabilityPerMinute();
        } else {
            String userId = authenticatedUserId();
            if (userId != null) {
                key = KEY_PREFIX + "user:" + userId + ":" + window;
                limit = limits.getPerUserPerMinute();
            } else if (IP_EXEMPT_PATHS.contains(path)) {
                filterChain.doFilter(request, response);
                return;
            } else {
                key = KEY_PREFIX + "ip:" + clientIp(request) + ":" + window;
                limit = limits.getPerIpPerMinute();
            }
        }

        long count;
        try {
            count = rateLimiter.increment(key, KEY_TTL);
        } catch (RuntimeException e) {
            log.warn("Rate limiter unavailable, allowing request: {}", e.getClass().getSimpleName());
            filterChain.doFilter(request, response);
            return;
        }

        response.setHeader("X-RateLimit-Limit", String.valueOf(limit));
        response.setHeader("X-RateLimit-Remaining", String.valueOf(Math.max(0, limit - count)));
        if (count > limit) {
            response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
            response.setHeader("Retry-After", String.valueOf(retryAfter));
            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
            response.getWriter().write(
                    "{\"error\":\"Too many requests. Please slow down.\",\"code\":\"RATE_LIMIT_EXCEEDED\"}");
            return;
        }
        filterChain.doFilter(request, response);
    }

    /**
     * The decoded path within the application: percent-encoding resolved, {@code ;params}
     * removed and duplicate slashes collapsed ({@link UrlPathHelper#defaultInstance}), then
     * trailing slashes trimmed and lower-cased.
     */
    static String path(HttpServletRequest request) {
        String path = UrlPathHelper.defaultInstance.getPathWithinApplication(request);
        // Normalise trailing slashes so "/login/" counts against the login bucket too
        while (path.length() > 1 && path.endsWith("/")) {
            path = path.substring(0, path.length() - 1);
        }
        return path.toLowerCase(Locale.ROOT);
    }

    private static String authenticatedUserId() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated() || auth instanceof AnonymousAuthenticationToken) {
            return null;
        }
        return auth.getName();
    }

    private static String clientIp(HttpServletRequest request) {
        String ip = request.getRemoteAddr();
        return ip == null || ip.isBlank() ? "unknown" : ip;
    }
}
