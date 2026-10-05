package com.meeplehearth.auth.service;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.meeplehearth.auth.dto.AuthResponse;
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
import io.jsonwebtoken.Jwts;
import jakarta.mail.Session;
import jakarta.mail.internet.MimeMessage;
import jakarta.servlet.http.Cookie;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mock.env.MockEnvironment;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
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
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Branches of the auth services that the HTTP integration tests cannot reach with the local
 * profile (production cookie flags, cookie domain, missing allowed-origins) or that depend on
 * rare races and malformed inputs.
 */
class AuthUnitEdgeCasesTest {

    // ------------------------------------------------------------------ AuthService

    private final UserRepository userRepository = mock(UserRepository.class);
    private final RefreshTokenRepository refreshTokenRepository = mock(RefreshTokenRepository.class);
    private final EmailVerificationTokenRepository evRepository = mock(EmailVerificationTokenRepository.class);
    private final JavaMailSender mailSender = mock(JavaMailSender.class);
    private final RedisRateLimiter rateLimiter = mock(RedisRateLimiter.class);
    private final ApplicationEventPublisher eventPublisher = mock(ApplicationEventPublisher.class);
    private final PasswordResetTokenRepository resetRepository = mock(PasswordResetTokenRepository.class);
    private final GoogleAuthService googleAuthService = mock(GoogleAuthService.class);
    private final StringRedisTemplate redisTemplate = mock(StringRedisTemplate.class);
    private final AppProperties props = new AppProperties();
    private final User user = new User();

    private AuthService authService(String... profiles) {
        JwtUtil jwtUtil = mock(JwtUtil.class);
        when(jwtUtil.generateAccessToken(any(), anyInt())).thenReturn("access-jwt");
        when(jwtUtil.generateRefreshToken()).thenReturn("refresh-raw");
        PasswordEncoder encoder = mock(PasswordEncoder.class);
        when(encoder.encode(anyString())).thenReturn("encoded");
        when(encoder.matches("pw", "hash")).thenReturn(true);
        when(rateLimiter.tryAcquire(anyString(), anyLong(), any(Duration.class))).thenReturn(true);
        when(mailSender.createMimeMessage()).thenAnswer(inv -> new MimeMessage((Session) null));
        props.getJwt().setAccessTokenExpiryMs(900_000);
        props.getJwt().setRefreshTokenExpiryDays(30);

        user.setId(UUID.randomUUID());
        user.setUsername("player");
        user.setEmail("player@example.com");
        user.setPasswordHash("hash");
        user.setEmailVerified(true);
        when(userRepository.findById(user.getId())).thenReturn(Optional.of(user));
        when(userRepository.findByUsernameIgnoreCase("player")).thenReturn(Optional.of(user));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        MockEnvironment env = new MockEnvironment();
        env.setActiveProfiles(profiles);
        return new AuthService(userRepository, refreshTokenRepository, evRepository,
                resetRepository, jwtUtil, encoder, redisTemplate,
                mailSender, props, env, googleAuthService, rateLimiter, eventPublisher);
    }

    @Test
    void productionCookiesAreSecureAndScopedToTheConfiguredDomain() {
        props.getAuth().setCookieDomain(".meeple.example.com");
        AuthService service = authService("prod");
        MockHttpServletResponse response = new MockHttpServletResponse();

        AuthResponse auth = service.login(new com.meeplehearth.auth.dto.LoginRequest("player", "pw"), "198.51.100.1", response);

        assertThat(auth.id()).isEqualTo(user.getId());
        assertThat(response.getHeaders("Set-Cookie")).hasSize(2).allSatisfy(cookie -> assertThat(cookie)
                .contains("Secure").contains("HttpOnly").contains("Domain=.meeple.example.com").contains("SameSite=Lax"));

        MockHttpServletResponse logout = new MockHttpServletResponse();
        service.logout(new MockHttpServletRequest(), logout);
        // Clearing must use the same domain, or the browser keeps the original cookies
        assertThat(logout.getHeaders("Set-Cookie")).hasSize(2).allSatisfy(cookie -> assertThat(cookie)
                .contains("Max-Age=0").contains("Domain=.meeple.example.com").contains("Secure"));
        verify(refreshTokenRepository, never()).deleteByTokenHash(anyString());
    }

    @Test
    void blankCookieDomainIsIgnoredAndStagingIsAlsoSecure() {
        props.getAuth().setCookieDomain("  ");
        AuthService service = authService("staging");
        MockHttpServletResponse response = new MockHttpServletResponse();

        service.login(new com.meeplehearth.auth.dto.LoginRequest("player", "pw"), null, response);

        assertThat(response.getHeaders("Set-Cookie")).allSatisfy(cookie ->
                assertThat(cookie).contains("Secure").doesNotContain("Domain="));
        MockHttpServletResponse logout = new MockHttpServletResponse();
        service.logout(new MockHttpServletRequest(), logout);
        assertThat(logout.getHeaders("Set-Cookie")).allSatisfy(cookie -> assertThat(cookie).doesNotContain("Domain="));
    }

    @Test
    void emailLinksFallBackToLocalhostWhenNoFrontendOriginIsConfigured() throws Exception {
        props.getCors().setAllowedOrigins(java.util.List.of());
        AuthService service = authService();
        user.setEmailVerified(false);
        when(userRepository.findByEmailIgnoreCase("player@example.com")).thenReturn(Optional.of(user));

        service.resendVerification("player@example.com", "198.51.100.1");
        service.forgotPassword("player@example.com", "198.51.100.1");

        ArgumentCaptor<MimeMessage> captor = ArgumentCaptor.forClass(MimeMessage.class);
        verify(mailSender, org.mockito.Mockito.times(2)).send(captor.capture());
        assertThat(text(captor.getAllValues().get(0))).contains("http://localhost:5173/auth/verify-email?token=");
        assertThat(text(captor.getAllValues().get(1))).contains("http://localhost:5173/auth/reset-password?token=");
    }

    private static String text(MimeMessage message) throws Exception {
        Object content = message.getContent();
        StringBuilder out = new StringBuilder();
        collect(content, out);
        return out.toString();
    }

    private static void collect(Object content, StringBuilder out) throws Exception {
        if (content instanceof String s) {
            out.append(s);
        } else if (content instanceof jakarta.mail.Multipart multipart) {
            for (int i = 0; i < multipart.getCount(); i++) {
                collect(multipart.getBodyPart(i).getContent(), out);
            }
        }
    }

    @Test
    void resettingThePasswordOfAVanishedUserIsNotFound() {
        AuthService service = authService();
        var token = new com.meeplehearth.auth.entity.PasswordResetToken();
        token.setUserId(UUID.randomUUID());
        token.setExpiresAt(Instant.now().plusSeconds(60));
        when(resetRepository.findByTokenHash(anyString())).thenReturn(Optional.of(token));

        assertThatThrownBy(() -> service.resetPassword("raw", "new-password"))
                .isInstanceOf(ApiException.class)
                .extracting("status").isEqualTo(HttpStatus.NOT_FOUND);
        verify(eventPublisher, never()).publishEvent(any(Object.class));
    }

    @Test
    void blankClientIpSharesTheUnknownLockoutBucket() {
        AuthService service = authService();
        when(rateLimiter.increment(anyString(), any(Duration.class))).thenReturn(1L);

        assertThatThrownBy(() -> service.login(new com.meeplehearth.auth.dto.LoginRequest("player", "wrong"), "  ",
                new MockHttpServletResponse())).isInstanceOf(ApiException.class);

        verify(rateLimiter).increment(org.mockito.ArgumentMatchers.eq("auth:login:failures:u:" + user.getId() + ":unknown"),
                any(Duration.class));
    }

    @Test
    void emailMatchAlreadyCarryingTheSameGoogleIdIsSimplyLoggedIn() {
        AuthService service = authService();
        user.setGoogleId("google-sub");
        user.setOnboardingCompleted(true);
        when(googleAuthService.verify("id-token")).thenReturn(
                new GoogleAuthService.GoogleUserInfo("google-sub", "player@example.com", "Player", null));
        when(userRepository.findByGoogleId("google-sub")).thenReturn(Optional.empty());
        when(userRepository.findByEmailIgnoreCase("player@example.com")).thenReturn(Optional.of(user));

        AuthResponse response = service.googleLogin("id-token", new MockHttpServletResponse());

        assertThat(response.id()).isEqualTo(user.getId());
        assertThat(user.getTokenVersion()).isZero();
        verify(eventPublisher, never()).publishEvent(any(Object.class));
    }

    @Test
    void passwordResetMailFailureIsSwallowed() {
        AuthService service = authService();
        when(userRepository.findByEmailIgnoreCase("player@example.com")).thenReturn(Optional.of(user));
        when(mailSender.createMimeMessage()).thenThrow(new IllegalStateException("mail session unavailable"));

        assertThat(service.forgotPassword("player@example.com", "198.51.100.1").message())
                .startsWith("If that email is registered");
    }

    @Test
    void resendVerificationOverRateLimitDoesNotTouchTheDatabase() {
        AuthService service = authService();
        when(rateLimiter.tryAcquire(anyString(), anyLong(), any(Duration.class))).thenReturn(true, false);

        assertThat(service.resendVerification("player@example.com", "198.51.100.1").message())
                .startsWith("If that email exists");
        verify(userRepository, never()).findByEmailIgnoreCase(anyString());
    }

    @Test
    void verifyingATokenOfAVanishedUserIsNotFound() {
        AuthService service = authService();
        var token = new com.meeplehearth.auth.entity.EmailVerificationToken();
        token.setUserId(UUID.randomUUID());
        token.setExpiresAt(Instant.now().plusSeconds(60));
        when(evRepository.findByTokenHash(anyString())).thenReturn(Optional.of(token));

        assertThatThrownBy(() -> service.verifyEmail("raw", new MockHttpServletResponse()))
                .isInstanceOf(ApiException.class)
                .extracting("status").isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void refreshOfAVanishedUserIsUnauthorized() {
        AuthService service = authService();
        RefreshToken stored = new RefreshToken();
        stored.setUserId(UUID.randomUUID());
        stored.setTokenHash("h");
        stored.setExpiresAt(Instant.now().plusSeconds(60));
        when(refreshTokenRepository.findByTokenHash(anyString())).thenReturn(Optional.of(stored));
        when(refreshTokenRepository.markUsed(anyString(), any())).thenReturn(1);
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setCookies(new Cookie("refresh_token", "raw"));

        assertThatThrownBy(() -> service.refresh(request, new MockHttpServletResponse()))
                .isInstanceOf(ApiException.class)
                .hasMessage("User not found");
    }

    @Test
    void replayWhoseSuccessorVanishedWithoutAConcurrentRecoveryIsTreatedAsTheft() {
        AuthService service = authService();
        UUID successorId = UUID.randomUUID();
        RefreshToken stored = new RefreshToken();
        stored.setId(UUID.randomUUID());
        stored.setUserId(user.getId());
        stored.setTokenHash("h");
        stored.setExpiresAt(Instant.now().plusSeconds(600));
        stored.setUsedAt(Instant.now().minusSeconds(120));
        stored.setReplacedBy(successorId);
        when(refreshTokenRepository.findByTokenHash(anyString())).thenReturn(Optional.of(stored));
        when(refreshTokenRepository.findById(successorId)).thenReturn(Optional.empty());
        // The successor link still points at the deleted token: nobody re-issued concurrently
        when(refreshTokenRepository.findReplacedById(stored.getId())).thenReturn(Optional.of(successorId));
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setCookies(new Cookie("other", "x"), new Cookie("refresh_token", "raw"));

        assertThatThrownBy(() -> service.refresh(request, new MockHttpServletResponse()))
                .isInstanceOf(ApiException.class)
                .extracting("status").isEqualTo(HttpStatus.UNAUTHORIZED);
        verify(refreshTokenRepository).deleteByUserId(user.getId());
        verify(eventPublisher).publishEvent(new UserSessionsRevokedEvent(user.getId()));
        assertThat(user.getTokenVersion()).isEqualTo(1);
    }

    @Test
    void replayOfAnUnlinkedTokenForAVanishedUserStillClearsSessions() {
        AuthService service = authService();
        RefreshToken stored = new RefreshToken();
        UUID ghost = UUID.randomUUID();
        stored.setUserId(ghost);
        stored.setTokenHash("h");
        stored.setExpiresAt(Instant.now().plusSeconds(600));
        stored.setUsedAt(Instant.now().minusSeconds(120));
        when(refreshTokenRepository.findByTokenHash(anyString())).thenReturn(Optional.of(stored));
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setCookies(new Cookie("refresh_token", "raw"));
        MockHttpServletResponse response = new MockHttpServletResponse();

        assertThatThrownBy(() -> service.refresh(request, response)).isInstanceOf(ApiException.class);

        verify(refreshTokenRepository).deleteByUserId(ghost);
        verify(eventPublisher, never()).publishEvent(any(Object.class));
        assertThat(response.getHeaders("Set-Cookie")).hasSize(2);
    }

    @Test
    void lostRaceForAnUnusedSuccessorFallsBackToTheRemainingState() {
        AuthService service = authService();
        UUID successorId = UUID.randomUUID();
        RefreshToken stored = new RefreshToken();
        stored.setId(UUID.randomUUID());
        stored.setUserId(user.getId());
        stored.setTokenHash("h");
        stored.setExpiresAt(Instant.now().plusSeconds(600));
        stored.setUsedAt(Instant.now().minusSeconds(120));
        stored.setReplacedBy(successorId);
        RefreshToken unused = new RefreshToken();
        RefreshToken usedMeanwhile = new RefreshToken();
        usedMeanwhile.setUsedAt(Instant.now());
        when(refreshTokenRepository.findByTokenHash(anyString())).thenReturn(Optional.of(stored));
        // Unused at first, but another request used it before our delete
        when(refreshTokenRepository.findById(successorId)).thenReturn(Optional.of(unused), Optional.of(usedMeanwhile));
        when(refreshTokenRepository.deleteUnusedById(successorId)).thenReturn(0);
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setCookies(new Cookie("refresh_token", "raw"));

        assertThatThrownBy(() -> service.refresh(request, new MockHttpServletResponse()))
                .isInstanceOf(ApiException.class)
                .extracting("status").isEqualTo(HttpStatus.UNAUTHORIZED);
        verify(refreshTokenRepository).deleteByUserId(user.getId());
    }

    // ------------------------------------------------------------------ UserDetailsServiceImpl

    @Test
    void userDetailsAreLoadedByIdAndCarryTheRole() {
        UserRepository repo = mock(UserRepository.class);
        UserDetailsServiceImpl service = new UserDetailsServiceImpl(repo);
        User admin = new User();
        admin.setId(UUID.randomUUID());
        admin.setRole("ADMIN");
        admin.setTokenVersion(2);
        when(repo.findById(admin.getId())).thenReturn(Optional.of(admin));

        UserDetails details = service.loadUserByUsername(admin.getId().toString());

        assertThat(details.getUsername()).isEqualTo(admin.getId().toString());
        // Google-only accounts have no password hash
        assertThat(details.getPassword()).isEmpty();
        assertThat(details.getAuthorities()).extracting(Object::toString).containsExactly("ROLE_ADMIN");

        admin.setPasswordHash("bcrypt");
        assertThat(service.loadUserForAccessToken(admin.getId(), 2).getPassword()).isEqualTo("bcrypt");
    }

    @Test
    void userDetailsRejectMalformedMissingDeletedAndRevoked() {
        UserRepository repo = mock(UserRepository.class);
        UserDetailsServiceImpl service = new UserDetailsServiceImpl(repo);
        User deleted = new User();
        deleted.setId(UUID.randomUUID());
        deleted.setDeletedAt(Instant.now());
        User active = new User();
        active.setId(UUID.randomUUID());
        active.setTokenVersion(3);
        when(repo.findById(deleted.getId())).thenReturn(Optional.of(deleted));
        when(repo.findById(active.getId())).thenReturn(Optional.of(active));

        assertThatThrownBy(() -> service.loadUserByUsername("not-a-uuid"))
                .isInstanceOf(UsernameNotFoundException.class).hasMessageContaining("Invalid user ID");
        assertThatThrownBy(() -> service.loadUserByUsername(UUID.randomUUID().toString()))
                .isInstanceOf(UsernameNotFoundException.class).hasMessageContaining("not found");
        assertThatThrownBy(() -> service.loadUserByUsername(deleted.getId().toString()))
                .isInstanceOf(UsernameNotFoundException.class).hasMessageContaining("deleted");
        assertThatThrownBy(() -> service.loadUserForAccessToken(active.getId(), 2))
                .isInstanceOf(UsernameNotFoundException.class).hasMessageContaining("revoked");
    }

    // ------------------------------------------------------------------ JwtUtil

    private static JwtUtil jwtUtil(long expiryMs) {
        AppProperties p = new AppProperties();
        p.getJwt().setSecret("local-dev-secret-must-be-at-least-256-bits-long-xx");
        p.getJwt().setAccessTokenExpiryMs(expiryMs);
        return new JwtUtil(p);
    }

    @Test
    void accessTokenRoundTripsToTheUserId() {
        JwtUtil util = jwtUtil(60_000);
        UUID id = UUID.randomUUID();

        String token = util.generateAccessToken(id, 4);

        assertThat(util.getUserIdFromToken(token)).isEqualTo(id);
        var claims = util.validateAccessToken(token);
        assertThat(JwtUtil.getTokenVersion(claims)).isEqualTo(4);
        assertThat(claims.getExpiration().getTime() - claims.getIssuedAt().getTime()).isEqualTo(60_000);
    }

    @Test
    void expiredAndNonAccessTokensAreRejected() {
        JwtUtil util = jwtUtil(-1_000);
        String expired = util.generateAccessToken(UUID.randomUUID(), 0);
        String refreshTyped = Jwts.builder().subject(UUID.randomUUID().toString()).claim("type", "refresh")
                .signWith(io.jsonwebtoken.security.Keys.hmacShaKeyFor(
                        "local-dev-secret-must-be-at-least-256-bits-long-xx".getBytes()))
                .compact();

        for (String token : new String[]{expired, refreshTyped, "", "a.b.c"}) {
            assertThatThrownBy(() -> util.validateAccessToken(token)).as(token)
                    .isInstanceOf(ApiException.class)
                    .extracting("status").isEqualTo(HttpStatus.UNAUTHORIZED);
        }
    }

    @Test
    void refreshTokensAreLongRandomHex() {
        JwtUtil util = jwtUtil(60_000);

        String a = util.generateRefreshToken();
        String b = util.generateRefreshToken();

        assertThat(a).matches("[0-9a-f]{128}");
        assertThat(a).isNotEqualTo(b);
    }

    @Test
    void nonNumericTokenVersionClaimCountsAsZero() {
        assertThat(JwtUtil.getTokenVersion(Jwts.claims().add(JwtUtil.TOKEN_VERSION_CLAIM, "7").build())).isZero();
        assertThat(JwtUtil.getTokenVersion(Jwts.claims().add(JwtUtil.TOKEN_VERSION_CLAIM, 7L).build())).isEqualTo(7);
    }

    // ------------------------------------------------------------------ GoogleAuthService

    private static GoogleAuthService.GoogleUserInfo info(GoogleIdToken.Payload payload) {
        return GoogleAuthService.toUserInfo(payload);
    }

    @Test
    void googlePayloadWithoutSubjectOrEmailIsRejected() {
        GoogleIdToken.Payload noSubject = new GoogleIdToken.Payload();
        noSubject.setEmail("a@example.com");
        noSubject.setEmailVerified(true);
        GoogleIdToken.Payload blankSubject = noSubject.clone().setSubject(" ");
        GoogleIdToken.Payload noEmail = new GoogleIdToken.Payload().setSubject("sub").setEmailVerified(true);
        GoogleIdToken.Payload blankEmail = new GoogleIdToken.Payload().setSubject("sub").setEmail(" ").setEmailVerified(true);

        assertThatThrownBy(() -> info(null)).isInstanceOf(ApiException.class).extracting("code").isEqualTo("INVALID_GOOGLE_TOKEN");
        assertThatThrownBy(() -> info(noSubject)).isInstanceOf(ApiException.class).extracting("code").isEqualTo("INVALID_GOOGLE_TOKEN");
        assertThatThrownBy(() -> info(blankSubject)).isInstanceOf(ApiException.class).extracting("code").isEqualTo("INVALID_GOOGLE_TOKEN");
        assertThatThrownBy(() -> info(noEmail)).isInstanceOf(ApiException.class).extracting("code").isEqualTo("GOOGLE_EMAIL_NOT_VERIFIED");
        assertThatThrownBy(() -> info(blankEmail)).isInstanceOf(ApiException.class).extracting("code").isEqualTo("GOOGLE_EMAIL_NOT_VERIFIED");
    }

    @Test
    void googleVerifierThatReturnsNullOrThrowsIsUnauthorized() throws Exception {
        GoogleIdTokenVerifier verifier = mock(GoogleIdTokenVerifier.class);
        when(verifier.verify("null-token")).thenReturn(null);
        when(verifier.verify("io-failure")).thenThrow(new java.io.IOException("certs unavailable"));
        GoogleAuthService service = new GoogleAuthService(verifier);

        assertThatThrownBy(() -> service.verify("null-token")).isInstanceOf(ApiException.class)
                .hasMessage("Invalid Google ID token");
        assertThatThrownBy(() -> service.verify("io-failure")).isInstanceOf(ApiException.class)
                .hasMessage("Could not verify Google token");
    }

    @Test
    void productionConstructorBuildsAVerifierThatRejectsGarbageOffline() {
        AppProperties p = new AppProperties();
        p.getGoogle().setClientId("client-id.apps.googleusercontent.com");

        GoogleAuthService service = new GoogleAuthService(p);

        // A malformed token fails parsing before any network call
        assertThatThrownBy(() -> service.verify("not-a-jwt"))
                .isInstanceOf(ApiException.class)
                .extracting("code").isEqualTo("INVALID_GOOGLE_TOKEN");
    }
}
