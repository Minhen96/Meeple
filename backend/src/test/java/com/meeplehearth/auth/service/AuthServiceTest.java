package com.meeplehearth.auth.service;

import com.meeplehearth.auth.dto.LoginRequest;
import com.meeplehearth.auth.dto.MessageResponse;
import com.meeplehearth.auth.entity.RefreshToken;
import com.meeplehearth.auth.event.UserSessionsRevokedEvent;
import com.meeplehearth.auth.repository.EmailVerificationTokenRepository;
import com.meeplehearth.auth.repository.PasswordResetTokenRepository;
import com.meeplehearth.auth.repository.RefreshTokenRepository;
import com.meeplehearth.auth.util.JwtUtil;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.common.ratelimit.RedisRateLimiter;
import com.meeplehearth.config.AppProperties;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import jakarta.servlet.http.Cookie;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.core.env.Environment;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.Duration;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AuthServiceTest {

    private UserRepository userRepository;
    private RefreshTokenRepository refreshTokenRepository;
    private EmailVerificationTokenRepository emailVerificationTokenRepository;
    private PasswordEncoder passwordEncoder;
    private StringRedisTemplate redisTemplate;
    private JavaMailSender mailSender;
    private GoogleAuthService googleAuthService;
    private RedisRateLimiter rateLimiter;
    private ApplicationEventPublisher eventPublisher;
    private AuthService authService;

    private final UUID userId = UUID.randomUUID();
    private User user;

    @BeforeEach
    void setUp() {
        userRepository = mock(UserRepository.class);
        refreshTokenRepository = mock(RefreshTokenRepository.class);
        emailVerificationTokenRepository = mock(EmailVerificationTokenRepository.class);
        passwordEncoder = mock(PasswordEncoder.class);
        redisTemplate = mock(StringRedisTemplate.class);
        mailSender = mock(JavaMailSender.class);
        googleAuthService = mock(GoogleAuthService.class);
        rateLimiter = mock(RedisRateLimiter.class);
        eventPublisher = mock(ApplicationEventPublisher.class);
        JwtUtil jwtUtil = mock(JwtUtil.class);
        when(jwtUtil.generateAccessToken(any(), anyInt())).thenReturn("access-jwt");
        when(jwtUtil.generateRefreshToken()).thenReturn("new-refresh-token");
        when(rateLimiter.increment(anyString(), any(Duration.class))).thenReturn(1L);
        when(rateLimiter.tryAcquire(anyString(), anyLong(), any(Duration.class))).thenReturn(true);

        AppProperties props = new AppProperties();
        props.getJwt().setAccessTokenExpiryMs(900_000);
        props.getJwt().setRefreshTokenExpiryDays(30);

        authService = new AuthService(userRepository, refreshTokenRepository, emailVerificationTokenRepository,
                mock(PasswordResetTokenRepository.class), jwtUtil, passwordEncoder, redisTemplate, mailSender,
                props, mock(Environment.class), googleAuthService, rateLimiter,
                eventPublisher);

        user = new User();
        user.setId(userId);
        user.setEmail("player@example.com");
        user.setUsername("player");
        user.setEmailVerified(true);
        user.setPasswordHash("hash");
        when(userRepository.findById(userId)).thenReturn(Optional.of(user));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    private static MockHttpServletRequest requestWithRefreshCookie(String raw) {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setCookies(new Cookie("refresh_token", raw));
        return request;
    }

    private RefreshToken storedToken(Instant usedAt) {
        RefreshToken token = new RefreshToken();
        token.setUserId(userId);
        token.setTokenHash("hash");
        token.setExpiresAt(Instant.now().plus(Duration.ofDays(1)));
        token.setUsedAt(usedAt);
        return token;
    }

    // ---------------------------------------------------------------- refresh rotation

    @Test
    void refreshTokenCanBeRotatedOnlyOnce() {
        when(refreshTokenRepository.findByTokenHash(anyString())).thenReturn(Optional.of(storedToken(null)));
        // First rotation wins the conditional update, a concurrent duplicate updates no rows
        when(refreshTokenRepository.markUsed(anyString(), any(Instant.class))).thenReturn(1, 0);

        MockHttpServletResponse first = new MockHttpServletResponse();
        authService.refresh(requestWithRefreshCookie("raw"), first);
        assertThat(first.getHeaders("Set-Cookie")).anyMatch(c -> c.startsWith("refresh_token=new-refresh-token"));

        assertThatThrownBy(() -> authService.refresh(requestWithRefreshCookie("raw"), new MockHttpServletResponse()))
                .isInstanceOf(ApiException.class)
                .extracting("status").isEqualTo(HttpStatus.UNAUTHORIZED);

        verify(refreshTokenRepository, times(1)).save(any(RefreshToken.class));
        verify(refreshTokenRepository, never()).deleteByUserId(any());
    }

    @Test
    void reusingRotatedTokenRevokesAllSessions() {
        when(refreshTokenRepository.findByTokenHash(anyString()))
                .thenReturn(Optional.of(storedToken(Instant.now().minus(Duration.ofMinutes(5)))));

        assertThatThrownBy(() -> authService.refresh(requestWithRefreshCookie("raw"), new MockHttpServletResponse()))
                .isInstanceOf(ApiException.class);

        verify(refreshTokenRepository).deleteByUserId(userId);
        assertThat(user.getTokenVersion()).isEqualTo(1);
        verify(eventPublisher).publishEvent(new UserSessionsRevokedEvent(userId));
        verify(refreshTokenRepository, never()).markUsed(anyString(), any());
        verify(refreshTokenRepository, never()).save(any(RefreshToken.class));
    }

    @Test
    void reuseWithinGraceWindowIsRejectedWithoutRevocation() {
        when(refreshTokenRepository.findByTokenHash(anyString())).thenReturn(Optional.of(storedToken(Instant.now())));

        assertThatThrownBy(() -> authService.refresh(requestWithRefreshCookie("raw"), new MockHttpServletResponse()))
                .isInstanceOf(ApiException.class);

        verify(refreshTokenRepository, never()).deleteByUserId(any());
        assertThat(user.getTokenVersion()).isZero();
        verify(eventPublisher, never()).publishEvent(any(Object.class));
    }

    @Test
    void refreshCookieIsHttpOnlyLax() {
        when(refreshTokenRepository.findByTokenHash(anyString())).thenReturn(Optional.of(storedToken(null)));
        when(refreshTokenRepository.markUsed(anyString(), any(Instant.class))).thenReturn(1);

        MockHttpServletResponse response = new MockHttpServletResponse();
        authService.refresh(requestWithRefreshCookie("raw"), response);

        assertThat(response.getHeaders("Set-Cookie"))
                .filteredOn(c -> c.startsWith("refresh_token="))
                .singleElement().asString().contains("HttpOnly").contains("SameSite=Lax");
    }

    // ---------------------------------------------------------------- login

    @Test
    void passwordlessUserCannotPasswordLogin() {
        user.setPasswordHash(null);
        when(userRepository.findByEmailIgnoreCase("player@example.com")).thenReturn(Optional.of(user));

        assertThatThrownBy(() -> authService.login(
                new LoginRequest("player@example.com", "anything"), "203.0.113.5", new MockHttpServletResponse()))
                .isInstanceOf(ApiException.class)
                .extracting("status").isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void unverifiedAccountWithWrongPasswordGetsGenericError() {
        user.setEmailVerified(false);
        when(userRepository.findByEmailIgnoreCase("player@example.com")).thenReturn(Optional.of(user));
        when(passwordEncoder.matches("wrong", "hash")).thenReturn(false);

        assertThatThrownBy(() -> authService.login(
                new LoginRequest("player@example.com", "wrong"), "203.0.113.5", new MockHttpServletResponse()))
                .isInstanceOf(ApiException.class)
                .extracting("code").isEqualTo("UNAUTHORIZED");
    }

    @Test
    void emailAndUsernameShareOneLockoutCounterScopedToIp() {
        when(userRepository.findByEmailIgnoreCase("player@example.com")).thenReturn(Optional.of(user));
        when(userRepository.findByUsernameIgnoreCase("player")).thenReturn(Optional.of(user));

        for (String identifier : new String[]{"player@example.com", "player"}) {
            assertThatThrownBy(() -> authService.login(
                    new LoginRequest(identifier, "wrong"), "203.0.113.5", new MockHttpServletResponse()))
                    .isInstanceOf(ApiException.class);
        }

        verify(rateLimiter, times(2)).increment(eq("auth:login:failures:u:" + userId + ":203.0.113.5"), any());
    }

    // ---------------------------------------------------------------- email rate limits

    @Test
    void forgotPasswordOverLimitReturnsGenericMessageWithoutSending() {
        when(rateLimiter.tryAcquire(anyString(), anyLong(), any(Duration.class))).thenReturn(false);

        MessageResponse response = authService.forgotPassword("player@example.com", "203.0.113.5");

        assertThat(response.message()).isEqualTo("If that email is registered, a password reset link has been sent.");
        verify(userRepository, never()).findByEmailIgnoreCase(anyString());
        verify(mailSender, never()).createMimeMessage();
    }

    // ---------------------------------------------------------------- Google linking

    @Test
    void googleLinkToUnverifiedAccountWipesPreRegisteredCredentials() {
        user.setEmailVerified(false);
        when(googleAuthService.verify("id-token")).thenReturn(
                new GoogleAuthService.GoogleUserInfo("google-sub", "player@example.com", "Player", null));
        when(userRepository.findByGoogleId("google-sub")).thenReturn(Optional.empty());
        when(userRepository.findByEmailIgnoreCase("player@example.com")).thenReturn(Optional.of(user));

        authService.googleLogin("id-token", new MockHttpServletResponse());

        assertThat(user.getGoogleId()).isEqualTo("google-sub");
        assertThat(user.isEmailVerified()).isTrue();
        assertThat(user.getPasswordHash()).isNull();
        assertThat(user.getTokenVersion()).isEqualTo(1);
        verify(emailVerificationTokenRepository).deleteByUserId(userId);
        verify(refreshTokenRepository).deleteByUserId(userId);
        verify(eventPublisher).publishEvent(new UserSessionsRevokedEvent(userId));
    }

    @Test
    void googleLinkToVerifiedAccountKeepsPassword() {
        when(googleAuthService.verify("id-token")).thenReturn(
                new GoogleAuthService.GoogleUserInfo("google-sub", "player@example.com", "Player", null));
        when(userRepository.findByGoogleId("google-sub")).thenReturn(Optional.empty());
        when(userRepository.findByEmailIgnoreCase("player@example.com")).thenReturn(Optional.of(user));

        authService.googleLogin("id-token", new MockHttpServletResponse());

        assertThat(user.getPasswordHash()).isEqualTo("hash");
        verify(refreshTokenRepository, never()).deleteByUserId(any());
        verify(eventPublisher, never()).publishEvent(any(Object.class));
    }
}
