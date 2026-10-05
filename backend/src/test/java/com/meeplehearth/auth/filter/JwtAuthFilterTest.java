package com.meeplehearth.auth.filter;

import com.meeplehearth.auth.service.UserDetailsServiceImpl;
import com.meeplehearth.auth.util.JwtUtil;
import com.meeplehearth.common.exception.ApiException;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import jakarta.servlet.http.Cookie;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.web.authentication.WebAuthenticationDetails;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class JwtAuthFilterTest {

    private final JwtUtil jwtUtil = mock(JwtUtil.class);
    private final UserDetailsServiceImpl userDetailsService = mock(UserDetailsServiceImpl.class);
    private final JwtAuthFilter filter = new JwtAuthFilter(jwtUtil, userDetailsService);
    private final UUID userId = UUID.randomUUID();

    @AfterEach
    void clearContext() {
        SecurityContextHolder.clearContext();
    }

    private Authentication run(MockHttpServletRequest request) throws Exception {
        MockFilterChain chain = new MockFilterChain() {
            Authentication seen;

            @Override
            public void doFilter(jakarta.servlet.ServletRequest req, jakarta.servlet.ServletResponse res) {
                seen = SecurityContextHolder.getContext().getAuthentication();
                req.setAttribute("seen", seen);
                try {
                    super.doFilter(req, res);
                } catch (Exception e) {
                    throw new IllegalStateException(e);
                }
            }
        };
        filter.doFilter(request, new MockHttpServletResponse(), chain);
        assertThat(chain.getRequest()).as("filter chain always continues").isSameAs(request);
        return (Authentication) request.getAttribute("seen");
    }

    private void stubValid(String token, int version) {
        Claims claims = Jwts.claims().subject(userId.toString()).add(JwtUtil.TOKEN_VERSION_CLAIM, version).build();
        when(jwtUtil.validateAccessToken(token)).thenReturn(claims);
        UserDetails details = User.withUsername(userId.toString()).password("").authorities("ROLE_ADMIN").build();
        when(userDetailsService.loadUserForAccessToken(userId, version)).thenReturn(details);
    }

    @Test
    void bearerHeaderAuthenticatesWithAuthoritiesAndRequestDetails() throws Exception {
        stubValid("header-jwt", 3);
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/users/me");
        request.addHeader("Authorization", "Bearer header-jwt");
        request.setCookies(new Cookie("access_token", "cookie-jwt"));
        request.setRemoteAddr("203.0.113.9");

        Authentication auth = run(request);

        assertThat(auth).isInstanceOf(UsernamePasswordAuthenticationToken.class);
        assertThat(auth.isAuthenticated()).isTrue();
        assertThat(((UserDetails) auth.getPrincipal()).getUsername()).isEqualTo(userId.toString());
        assertThat(auth.getAuthorities()).extracting(Object::toString).containsExactly("ROLE_ADMIN");
        assertThat(auth.getCredentials()).isNull();
        assertThat(((WebAuthenticationDetails) auth.getDetails()).getRemoteAddress()).isEqualTo("203.0.113.9");
        // The header takes precedence over the cookie
        verify(jwtUtil, never()).validateAccessToken("cookie-jwt");
    }

    @Test
    void accessTokenCookieIsUsedWhenThereIsNoBearerHeader() throws Exception {
        stubValid("cookie-jwt", 0);
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.addHeader("Authorization", "Token something");
        request.setCookies(new Cookie("other", "x"), new Cookie("access_token", "cookie-jwt"));

        assertThat(run(request)).isNotNull();
    }

    @Test
    void requestsWithoutAnyTokenContinueAnonymously() throws Exception {
        MockHttpServletRequest noCookies = new MockHttpServletRequest();
        assertThat(run(noCookies)).isNull();

        MockHttpServletRequest unrelatedCookie = new MockHttpServletRequest();
        unrelatedCookie.setCookies(new Cookie("theme", "dark"));
        assertThat(run(unrelatedCookie)).isNull();

        verify(jwtUtil, never()).validateAccessToken(any());
    }

    @Test
    void invalidOrRevokedTokensClearAnyExistingAuthentication() throws Exception {
        when(jwtUtil.validateAccessToken("bad")).thenThrow(ApiException.unauthorized("Invalid"));
        stubValid("revoked", 1);
        when(userDetailsService.loadUserForAccessToken(userId, 1)).thenThrow(new UsernameNotFoundException("revoked"));

        for (String token : new String[]{"bad", "revoked"}) {
            SecurityContextHolder.getContext().setAuthentication(
                    new UsernamePasswordAuthenticationToken("stale", null, java.util.List.of()));
            MockHttpServletRequest request = new MockHttpServletRequest();
            request.addHeader("Authorization", "Bearer " + token);

            assertThat(run(request)).as(token).isNull();
        }
    }
}
