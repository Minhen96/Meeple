package com.meeplehearth.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.net.URI;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * CSRF defence for cookie-authenticated requests: a state-changing request to /api/** whose
 * Origin (or, when Origin is absent, Referer) names a site outside app.cors.allowed-origins is
 * rejected. Requests carrying neither header (mobile clients, server-to-server) pass, since a
 * browser always sends Origin on cross-origin POST/PUT/PATCH/DELETE.
 */
public class OriginCheckFilter extends OncePerRequestFilter {

    private static final Set<String> STATE_CHANGING_METHODS = Set.of("POST", "PUT", "PATCH", "DELETE");

    private final Set<String> allowedOrigins;

    public OriginCheckFilter(List<String> allowedOrigins) {
        this.allowedOrigins = allowedOrigins.stream()
                .map(OriginCheckFilter::normalize)
                .collect(Collectors.toUnmodifiableSet());
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !STATE_CHANGING_METHODS.contains(request.getMethod().toUpperCase(Locale.ROOT))
                || !request.getRequestURI().startsWith(request.getContextPath() + "/api/");
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        if (!isAllowed(request.getHeader("Origin"), request.getHeader("Referer"))) {
            response.setStatus(HttpStatus.FORBIDDEN.value());
            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
            response.getWriter().write("{\"error\":\"Request origin is not allowed\",\"code\":\"INVALID_ORIGIN\"}");
            return;
        }
        filterChain.doFilter(request, response);
    }

    boolean isAllowed(String origin, String referer) {
        if (origin != null) {
            return allowedOrigins.contains(normalize(origin));
        }
        if (referer != null && !referer.isBlank()) {
            return allowedOrigins.contains(originOf(referer));
        }
        return true;
    }

    private static String originOf(String url) {
        try {
            URI uri = URI.create(url.trim());
            if (uri.getScheme() == null || uri.getHost() == null) {
                return "";
            }
            String port = uri.getPort() == -1 ? "" : ":" + uri.getPort();
            return normalize(uri.getScheme() + "://" + uri.getHost() + port);
        } catch (IllegalArgumentException e) {
            return "";
        }
    }

    private static String normalize(String origin) {
        String trimmed = origin.trim().toLowerCase(Locale.ROOT);
        return trimmed.endsWith("/") ? trimmed.substring(0, trimmed.length() - 1) : trimmed;
    }
}
