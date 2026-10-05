package com.meeplehearth.auth.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.meeplehearth.support.auth.AuthWebIntegrationTest;
import com.meeplehearth.user.entity.User;
import jakarta.servlet.http.Cookie;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.mail.MailSendException;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.test.web.servlet.MvcResult;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Email/password auth flows through the real HTTP layer, security filters, Postgres and Redis.
 */
class AuthControllerIntegrationTest extends AuthWebIntegrationTest {

    private MvcResult postJson(String path, Object body, Cookie... cookies) throws Exception {
        var request = post(path).with(fromClientIp())
                .contentType(MediaType.APPLICATION_JSON)
                .content(json(body));
        if (cookies.length > 0) {
            request.cookie(cookies);
        }
        return mockMvc.perform(request).andReturn();
    }

    private MvcResult login(String identifier, String password) throws Exception {
        return postJson("/api/v1/auth/login", Map.of("emailOrUsername", identifier, "password", password));
    }

    private static Cookie cookie(MockHttpServletResponse response, String name) {
        String value = setCookieValue(response, name);
        assertThat(value).as("Set-Cookie " + name).isNotNull().isNotEmpty();
        return new Cookie(name, value);
    }

    private int refreshTokenCount(UUID userId) {
        entityManager.flush();
        Integer count = jdbc.queryForObject("SELECT COUNT(*) FROM refresh_tokens WHERE user_id = ?", Integer.class, userId);
        return count == null ? 0 : count;
    }

    // ------------------------------------------------------------------ full flow

    @Test
    void registerVerifyLoginRefreshLogoutLifecycle() throws Exception {
        String username = uniqueName();
        String email = trackEmail(username.toUpperCase() + "@Example.TEST");

        MvcResult register = postJson("/api/v1/auth/register",
                Map.of("email", email, "username", username, "password", PASSWORD));
        assertThat(register.getResponse().getStatus()).isEqualTo(201);
        assertThat(body(register).at("/data/message").asText()).startsWith("Registration successful");

        User created = userRepository.findByUsernameIgnoreCase(username).orElseThrow();
        assertThat(created.getEmail()).isEqualTo(email.toLowerCase());
        assertThat(created.isEmailVerified()).isFalse();
        assertThat(created.getPasswordHash()).isNotEqualTo(PASSWORD);
        assertThat(passwordEncoder.matches(PASSWORD, created.getPasswordHash())).isTrue();

        var mail = sentMails(1).get(0);
        assertThat(mail.getSubject()).isEqualTo("Verify your Meeple account");
        assertThat(mail.getAllRecipients()[0].toString()).isEqualTo(email.toLowerCase());
        assertThat(textOf(mail.getContent())).contains(ALLOWED_ORIGIN + "/auth/verify-email?token=");

        // Unverified accounts cannot log in, even with the right password
        MvcResult unverified = login(username, PASSWORD);
        assertThat(unverified.getResponse().getStatus()).isEqualTo(400);
        assertThat(body(unverified).get("code").asText()).isEqualTo("EMAIL_NOT_VERIFIED");

        // Verifying logs the user in
        String verifyToken = tokenFromLastMail();
        MvcResult verified = postJson("/api/v1/auth/verify-email", Map.of("token", verifyToken));
        assertThat(verified.getResponse().getStatus()).isEqualTo(200);
        assertThat(body(verified).at("/data/username").asText()).isEqualTo(username);
        assertThat(body(verified).at("/data/onboardingCompleted").asBoolean()).isFalse();
        assertThat(setCookieHeader(verified.getResponse(), "access_token"))
                .contains("HttpOnly").contains("SameSite=Lax").contains("Path=/").contains("Max-Age=900")
                .doesNotContain("Secure");
        assertThat(reload(created.getId()).isEmailVerified()).isTrue();

        // A verification token is single use
        MvcResult reused = postJson("/api/v1/auth/verify-email", Map.of("token", verifyToken));
        assertThat(reused.getResponse().getStatus()).isEqualTo(400);
        assertThat(body(reused).get("code").asText()).isEqualTo("TOKEN_USED");

        // Login with email, case-insensitively
        MvcResult login = login(email.toUpperCase(), PASSWORD);
        assertThat(login.getResponse().getStatus()).isEqualTo(200);
        JsonNode loginBody = body(login);
        assertThat(loginBody.at("/data/id").asText()).isEqualTo(created.getId().toString());
        assertThat(loginBody.at("/data/email").asText()).isEqualTo(email.toLowerCase());
        Cookie access = cookie(login.getResponse(), "access_token");
        Cookie refresh = cookie(login.getResponse(), "refresh_token");
        assertThat(refresh.getValue()).matches("[0-9a-f]{128}");
        assertThat(setCookieHeader(login.getResponse(), "refresh_token")).contains("Max-Age=" + 30L * 24 * 60 * 60);

        mockMvc.perform(get("/api/v1/users/me").cookie(access))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.username").value(username));

        // Refresh rotates the refresh token
        MvcResult refreshed = postJson("/api/v1/auth/refresh", Map.of(), refresh);
        assertThat(refreshed.getResponse().getStatus()).isEqualTo(200);
        assertThat(body(refreshed).at("/data/id").asText()).isEqualTo(created.getId().toString());
        Cookie rotated = cookie(refreshed.getResponse(), "refresh_token");
        assertThat(rotated.getValue()).isNotEqualTo(refresh.getValue());
        Map<String, Object> oldRow = jdbc.queryForMap(
                "SELECT used_at, replaced_by FROM refresh_tokens WHERE token_hash = ?", sha256(refresh.getValue()));
        assertThat(oldRow.get("used_at")).isNotNull();
        assertThat(oldRow.get("replaced_by")).isNotNull();

        // Logout deletes the presented refresh token and clears both cookies
        MvcResult logout = postJson("/api/v1/auth/logout", Map.of(), rotated);
        assertThat(logout.getResponse().getStatus()).isEqualTo(200);
        assertThat(body(logout).at("/data/message").asText()).isEqualTo("Logged out successfully");
        assertThat(setCookieHeader(logout.getResponse(), "access_token")).startsWith("access_token=;").contains("Max-Age=0");
        assertThat(setCookieHeader(logout.getResponse(), "refresh_token")).startsWith("refresh_token=;").contains("Max-Age=0");

        MvcResult afterLogout = postJson("/api/v1/auth/refresh", Map.of(), rotated);
        assertThat(afterLogout.getResponse().getStatus()).isEqualTo(401);
        assertThat(body(afterLogout).get("error").asText()).isEqualTo("Invalid refresh token");
    }

    // ------------------------------------------------------------------ register


    @Test
    void rejectsInvalidPayloadWithFieldErrors() throws Exception {
        MvcResult result = postJson("/api/v1/auth/register",
                Map.of("email", "not-an-email", "username", "Bad Name", "password", "short"));

        assertThat(result.getResponse().getStatus()).isEqualTo(400);
        JsonNode body = body(result);
        assertThat(body.get("code").asText()).isEqualTo("VALIDATION_ERROR");
        assertThat(body.get("error").asText()).contains("email:").contains("username:").contains("password:");
        verify(mailSender, never()).send(any(jakarta.mail.internet.MimeMessage.class));
    }

    @Test
    void rejectsTakenEmailAndUsernameCaseInsensitively() throws Exception {
        User existing = persistUser(true);

        MvcResult emailTaken = postJson("/api/v1/auth/register",
                Map.of("email", existing.getEmail().toUpperCase(), "username", uniqueName(), "password", PASSWORD));
        assertThat(emailTaken.getResponse().getStatus()).isEqualTo(409);
        assertThat(body(emailTaken).get("code").asText()).isEqualTo("EMAIL_TAKEN");

        MvcResult usernameTaken = postJson("/api/v1/auth/register",
                Map.of("email", trackEmail(uniqueName() + "@example.test"), "username", existing.getUsername(),
                        "password", PASSWORD));
        assertThat(usernameTaken.getResponse().getStatus()).isEqualTo(409);
        assertThat(body(usernameTaken).get("code").asText()).isEqualTo("USERNAME_TAKEN");
    }

    @Test
    void registrationSucceedsEvenWhenTheEmailCannotBeSent() throws Exception {
        doThrow(new MailSendException("smtp down")).when(mailSender).send(any(jakarta.mail.internet.MimeMessage.class));
        String username = uniqueName();

        MvcResult result = postJson("/api/v1/auth/register",
                Map.of("email", trackEmail(username + "@example.test"), "username", username, "password", PASSWORD));

        assertThat(result.getResponse().getStatus()).isEqualTo(201);
        assertThat(userRepository.existsByUsernameIgnoreCase(username)).isTrue();
    }

    @Test
    void availabilityChecksReflectExistingAccounts() throws Exception {
        User existing = persistUser(true);

        mockMvc.perform(get("/api/v1/auth/check-username").param("username", existing.getUsername().toUpperCase()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.available").value(false));
        mockMvc.perform(get("/api/v1/auth/check-username").param("username", uniqueName()))
                .andExpect(jsonPath("$.data.available").value(true));
        mockMvc.perform(get("/api/v1/auth/check-email").param("email", existing.getEmail()))
                .andExpect(jsonPath("$.data.available").value(false));
        mockMvc.perform(get("/api/v1/auth/check-email").param("email", uniqueName() + "@example.test"))
                .andExpect(jsonPath("$.data.available").value(true));
    }

    // ------------------------------------------------------------------ login & lockout


    @Test
    void wrongPasswordAndUnknownAccountGetTheSameGenericError() throws Exception {
        User user = persistUser(true);

        MvcResult wrong = login(user.getUsername(), "wrong-password");
        MvcResult unknown = login(uniqueName() + "@example.test", PASSWORD);

        for (MvcResult result : new MvcResult[]{wrong, unknown}) {
            assertThat(result.getResponse().getStatus()).isEqualTo(401);
            assertThat(body(result).get("error").asText()).isEqualTo("Invalid credentials");
            assertThat(setCookieValue(result.getResponse(), "access_token")).isNull();
        }
    }

    @Test
    void loginByUsernameIsCaseInsensitiveAndTrimmed() throws Exception {
        User user = persistUser(true);

        MvcResult result = login("  " + user.getUsername().toUpperCase() + " ", PASSWORD);

        assertThat(result.getResponse().getStatus()).isEqualTo(200);
        assertThat(body(result).at("/data/id").asText()).isEqualTo(user.getId().toString());
    }

    @Test
    void blankCredentialsAreAValidationError() throws Exception {
        MvcResult result = login(" ", "");

        assertThat(result.getResponse().getStatus()).isEqualTo(400);
        assertThat(body(result).get("code").asText()).isEqualTo("VALIDATION_ERROR");
    }

    @Test
    void deactivatedAccountCannotLogIn() throws Exception {
        User user = persistUser(true);
        user.setDeletedAt(Instant.now());
        userRepository.saveAndFlush(user);

        MvcResult result = login(user.getUsername(), PASSWORD);

        assertThat(result.getResponse().getStatus()).isEqualTo(401);
        assertThat(body(result).get("error").asText()).isEqualTo("Account has been deactivated");
    }

    @Test
    void fiveFailuresLockTheAccountForThatClientIpOnly() throws Exception {
        User user = persistUser(true);
        String failKey = "auth:login:failures:u:" + user.getId() + ":" + clientIp;
        String lockKey = "auth:login:locked:u:" + user.getId() + ":" + clientIp;

        for (int i = 1; i <= 5; i++) {
            assertThat(login(i % 2 == 0 ? user.getEmail() : user.getUsername(), "wrong").getResponse().getStatus())
                    .isEqualTo(401);
        }
        assertThat(redis.opsForValue().get(failKey)).isEqualTo("5");
        assertThat(redis.getExpire(failKey)).isPositive();
        assertThat(redis.hasKey(lockKey)).isTrue();

        // Even the correct password is refused while locked
        MvcResult locked = login(user.getUsername(), PASSWORD);
        assertThat(locked.getResponse().getStatus()).isEqualTo(429);
        assertThat(body(locked).get("code").asText()).isEqualTo("TOO_MANY_REQUESTS");

        // The lock is scoped to the client IP: the owner on another network can still log in
        String otherIp = "192.0.2." + (1 + Math.abs(user.getId().hashCode() % 250));
        trackRedisKey("auth:login:failures:u:" + user.getId() + ":" + otherIp);
        trackRedisKey("auth:login:locked:u:" + user.getId() + ":" + otherIp);
        mockMvc.perform(post("/api/v1/auth/login")
                        .with(request -> {
                            request.setRemoteAddr(otherIp);
                            return request;
                        })
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("emailOrUsername", user.getUsername(), "password", PASSWORD))))
                .andExpect(status().isOk());
    }

    @Test
    void unknownIdentifiersAreLockedOutToo() throws Exception {
        String ghost = uniqueName();
        for (int i = 0; i < 5; i++) {
            login(ghost, "whatever");
        }
        assertThat(redis.hasKey("auth:login:locked:i:" + sha256(ghost) + ":" + clientIp)).isTrue();

        assertThat(login(ghost.toUpperCase(), "whatever").getResponse().getStatus()).isEqualTo(429);
    }

    @Test
    void successfulLoginResetsTheFailureCounter() throws Exception {
        User user = persistUser(true);
        String failKey = "auth:login:failures:u:" + user.getId() + ":" + clientIp;

        for (int i = 0; i < 4; i++) {
            login(user.getUsername(), "wrong");
        }
        assertThat(redis.opsForValue().get(failKey)).isEqualTo("4");

        assertThat(login(user.getUsername(), PASSWORD).getResponse().getStatus()).isEqualTo(200);
        assertThat(redis.hasKey(failKey)).isFalse();

        // The counter starts over: one more failure does not lock
        login(user.getUsername(), "wrong");
        assertThat(login(user.getUsername(), PASSWORD).getResponse().getStatus()).isEqualTo(200);
    }

    // ------------------------------------------------------------------ email verification


    @Test
    void missingBlankUnknownAndExpiredTokensAreRejected() throws Exception {
        MvcResult missing = postJson("/api/v1/auth/verify-email", Map.of());
        assertThat(missing.getResponse().getStatus()).isEqualTo(400);
        assertThat(body(missing).get("code").asText()).isEqualTo("MISSING_TOKEN");

        assertThat(body(postJson("/api/v1/auth/verify-email", Map.of("token", "  "))).get("code").asText())
                .isEqualTo("MISSING_TOKEN");

        MvcResult unknown = postJson("/api/v1/auth/verify-email", Map.of("token", "ab".repeat(32)));
        assertThat(unknown.getResponse().getStatus()).isEqualTo(400);
        assertThat(body(unknown).get("code").asText()).isEqualTo("INVALID_TOKEN");

        User user = persistUser(false);
        String raw = "cd".repeat(32);
        jdbc.update("INSERT INTO email_verification_tokens (user_id, token_hash, expires_at) VALUES (?, ?, ?)",
                user.getId(), sha256(raw), java.sql.Timestamp.from(Instant.now().minusSeconds(60)));

        MvcResult expired = postJson("/api/v1/auth/verify-email", Map.of("token", raw));
        assertThat(expired.getResponse().getStatus()).isEqualTo(400);
        assertThat(body(expired).get("code").asText()).isEqualTo("TOKEN_EXPIRED");
        assertThat(reload(user.getId()).isEmailVerified()).isFalse();
    }

    @Test
    void resendIssuesAWorkingTokenForUnverifiedAccountsOnly() throws Exception {
        User unverified = persistUser(false);
        User verified = persistUser(true);

        MvcResult resend = postJson("/api/v1/auth/resend-verification", Map.of("email", unverified.getEmail()));
        assertThat(resend.getResponse().getStatus()).isEqualTo(200);
        String genericMessage = body(resend).at("/data/message").asText();
        assertThat(genericMessage).startsWith("If that email exists");

        mockMvc.perform(post("/api/v1/auth/verify-email").contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("token", tokenFromLastMail()))))
                .andExpect(status().isOk());
        assertThat(reload(unverified.getId()).isEmailVerified()).isTrue();

        // Already verified and unknown addresses get the identical response but no email
        MvcResult alreadyVerified = postJson("/api/v1/auth/resend-verification", Map.of("email", verified.getEmail()));
        MvcResult unknown = postJson("/api/v1/auth/resend-verification",
                Map.of("email", trackEmail(uniqueName() + "@example.test")));
        assertThat(body(alreadyVerified).at("/data/message").asText()).isEqualTo(genericMessage);
        assertThat(body(unknown).at("/data/message").asText()).isEqualTo(genericMessage);
        assertThat(sentMails(1)).hasSize(1);
    }

    @Test
    void resendIsRateLimitedPerAddress() throws Exception {
        User unverified = persistUser(false);

        for (int i = 0; i < 4; i++) {
            assertThat(postJson("/api/v1/auth/resend-verification", Map.of("email", unverified.getEmail()))
                    .getResponse().getStatus()).isEqualTo(200);
        }

        // Three emails per address per hour; the fourth request is silently dropped
        assertThat(sentMails(3)).hasSize(3);
    }

    @Test
    void resendRequiresAnEmail() throws Exception {
        for (Map<String, String> body : List.of(Map.of("email", " "), Map.<String, String>of())) {
            MvcResult result = postJson("/api/v1/auth/resend-verification", body);

            assertThat(result.getResponse().getStatus()).isEqualTo(400);
            assertThat(body(result).get("code").asText()).isEqualTo("MISSING_EMAIL");
        }
    }

    @Test
    void resendIsSilentForDeletedAccounts() throws Exception {
        User deleted = persistUser(false);
        deleted.setDeletedAt(Instant.now());
        userRepository.saveAndFlush(deleted);

        MvcResult result = postJson("/api/v1/auth/resend-verification", Map.of("email", deleted.getEmail()));

        assertThat(result.getResponse().getStatus()).isEqualTo(200);
        verify(mailSender, never()).send(any(jakarta.mail.internet.MimeMessage.class));
    }

    // ------------------------------------------------------------------ password reset


    @Test
    void resetChangesPasswordAndRevokesEverySession() throws Exception {
        User user = persistUser(true);
        MvcResult login = login(user.getUsername(), PASSWORD);
        Cookie oldAccess = cookie(login.getResponse(), "access_token");
        Cookie oldRefresh = cookie(login.getResponse(), "refresh_token");
        assertThat(refreshTokenCount(user.getId())).isEqualTo(1);

        MvcResult forgot = postJson("/api/v1/auth/forgot-password", Map.of("email", " " + user.getEmail().toUpperCase()));
        assertThat(forgot.getResponse().getStatus()).isEqualTo(200);
        assertThat(body(forgot).at("/data/message").asText()).startsWith("If that email is registered");
        var mail = sentMails(1).get(0);
        assertThat(mail.getSubject()).isEqualTo("Reset your Meeple password");
        assertThat(textOf(mail.getContent())).contains(ALLOWED_ORIGIN + "/auth/reset-password?token=");
        String resetToken = tokenFromLastMail();

        MvcResult reset = postJson("/api/v1/auth/reset-password",
                Map.of("token", resetToken, "newPassword", "brand-new-password"));
        assertThat(reset.getResponse().getStatus()).isEqualTo(200);
        assertThat(body(reset).at("/data/message").asText()).startsWith("Password has been reset");

        User updated = reload(user.getId());
        assertThat(updated.getTokenVersion()).isEqualTo(1);
        assertThat(refreshTokenCount(user.getId())).isZero();

        // Old access token, old refresh token and old password no longer work
        mockMvc.perform(get("/api/v1/users/me").cookie(oldAccess)).andExpect(status().isUnauthorized());
        assertThat(postJson("/api/v1/auth/refresh", Map.of(), oldRefresh).getResponse().getStatus()).isEqualTo(401);
        assertThat(login(user.getUsername(), PASSWORD).getResponse().getStatus()).isEqualTo(401);
        assertThat(login(user.getUsername(), "brand-new-password").getResponse().getStatus()).isEqualTo(200);

        // The reset link is single use
        MvcResult reuse = postJson("/api/v1/auth/reset-password",
                Map.of("token", resetToken, "newPassword", "another-password"));
        assertThat(reuse.getResponse().getStatus()).isEqualTo(400);
        assertThat(body(reuse).get("code").asText()).isEqualTo("TOKEN_USED");
    }

    @Test
    void unknownAndDeletedAccountsGetTheGenericResponseWithoutEmail() throws Exception {
        User deleted = persistUser(true);
        deleted.setDeletedAt(Instant.now());
        userRepository.saveAndFlush(deleted);

        MvcResult unknown = postJson("/api/v1/auth/forgot-password",
                Map.of("email", trackEmail(uniqueName() + "@example.test")));
        MvcResult gone = postJson("/api/v1/auth/forgot-password", Map.of("email", deleted.getEmail()));

        assertThat(body(unknown).at("/data/message").asText()).isEqualTo(body(gone).at("/data/message").asText());
        verify(mailSender, never()).send(any(jakarta.mail.internet.MimeMessage.class));
    }

    @Test
    void forgotPasswordIsRateLimitedPerClientIp() throws Exception {
        User user = persistUser(true);
        for (int i = 0; i < 10; i++) {
            assertThat(postJson("/api/v1/auth/forgot-password",
                    Map.of("email", trackEmail(uniqueName() + "@example.test"))).getResponse().getStatus())
                    .isEqualTo(200);
        }

        // The 11th request from the same IP is dropped silently, even for a real account
        MvcResult limited = postJson("/api/v1/auth/forgot-password", Map.of("email", user.getEmail()));

        assertThat(limited.getResponse().getStatus()).isEqualTo(200);
        assertThat(body(limited).at("/data/message").asText()).startsWith("If that email is registered");
        assertThat(redis.opsForValue().get("auth:ratelimit:forgot-password:ip:" + clientIp)).isEqualTo("11");
        verify(mailSender, never()).send(any(jakarta.mail.internet.MimeMessage.class));
    }

    @Test
    void invalidResetRequestsAreRejected() throws Exception {
        MvcResult noToken = postJson("/api/v1/auth/reset-password", Map.of("newPassword", "long-enough-pw"));
        assertThat(body(noToken).get("code").asText()).isEqualTo("MISSING_TOKEN");

        MvcResult shortPassword = postJson("/api/v1/auth/reset-password", Map.of("token", "ab", "newPassword", "short"));
        assertThat(shortPassword.getResponse().getStatus()).isEqualTo(400);
        assertThat(body(shortPassword).get("code").asText()).isEqualTo("INVALID_PASSWORD");

        MvcResult noPassword = postJson("/api/v1/auth/reset-password", Map.of("token", "ab"));
        assertThat(body(noPassword).get("code").asText()).isEqualTo("INVALID_PASSWORD");

        MvcResult unknown = postJson("/api/v1/auth/reset-password",
                Map.of("token", "ef".repeat(32), "newPassword", "long-enough-pw"));
        assertThat(unknown.getResponse().getStatus()).isEqualTo(400);
        assertThat(body(unknown).get("code").asText()).isEqualTo("INVALID_TOKEN");

        MvcResult noEmail = postJson("/api/v1/auth/forgot-password", Map.of());
        assertThat(body(noEmail).get("code").asText()).isEqualTo("MISSING_EMAIL");
        MvcResult blankEmail = postJson("/api/v1/auth/forgot-password", Map.of("email", "  "));
        assertThat(body(blankEmail).get("code").asText()).isEqualTo("MISSING_EMAIL");

        MvcResult blankToken = postJson("/api/v1/auth/reset-password", Map.of("token", " ", "newPassword", "long-enough-pw"));
        assertThat(body(blankToken).get("code").asText()).isEqualTo("MISSING_TOKEN");
    }

    @Test
    void expiredResetTokenIsRejected() throws Exception {
        User user = persistUser(true);
        String raw = "12".repeat(32);
        jdbc.update("INSERT INTO password_reset_tokens (user_id, token_hash, expires_at) VALUES (?, ?, ?)",
                user.getId(), sha256(raw), java.sql.Timestamp.from(Instant.now().minusSeconds(1)));

        MvcResult result = postJson("/api/v1/auth/reset-password", Map.of("token", raw, "newPassword", "long-enough-pw"));

        assertThat(result.getResponse().getStatus()).isEqualTo(400);
        assertThat(body(result).get("code").asText()).isEqualTo("TOKEN_EXPIRED");
        assertThat(passwordEncoder.matches(PASSWORD, reload(user.getId()).getPasswordHash())).isTrue();
    }

    // ------------------------------------------------------------------ refresh rotation


    private Cookie[] loginCookies(User user) throws Exception {
        MvcResult login = login(user.getUsername(), PASSWORD);
        assertThat(login.getResponse().getStatus()).isEqualTo(200);
        return new Cookie[]{cookie(login.getResponse(), "access_token"), cookie(login.getResponse(), "refresh_token")};
    }

    /** Moves a token's used_at out of the 10 s concurrent-refresh grace window. */
    private void ageUsedAt(Cookie refresh) {
        entityManager.flush();
        jdbc.update("UPDATE refresh_tokens SET used_at = now() - interval '1 minute' WHERE token_hash = ?",
                sha256(refresh.getValue()));
        entityManager.clear();
    }

    @Test
    void missingOrUnknownRefreshTokenIsUnauthorized() throws Exception {
        MvcResult none = postJson("/api/v1/auth/refresh", Map.of());
        assertThat(none.getResponse().getStatus()).isEqualTo(401);
        assertThat(body(none).get("error").asText()).isEqualTo("No refresh token provided");

        MvcResult unknown = postJson("/api/v1/auth/refresh", Map.of(), new Cookie("refresh_token", "deadbeef"));
        assertThat(unknown.getResponse().getStatus()).isEqualTo(401);
    }

    @Test
    void expiredRefreshTokenIsDeleted() throws Exception {
        User user = persistUser(true);
        Cookie refresh = loginCookies(user)[1];
        entityManager.flush();
        jdbc.update("UPDATE refresh_tokens SET expires_at = now() - interval '1 second' WHERE token_hash = ?",
                sha256(refresh.getValue()));
        entityManager.clear();

        MvcResult result = postJson("/api/v1/auth/refresh", Map.of(), refresh);

        assertThat(result.getResponse().getStatus()).isEqualTo(401);
        assertThat(body(result).get("error").asText()).isEqualTo("Refresh token has expired");
        assertThat(refreshTokenCount(user.getId())).isZero();
    }

    @Test
    void concurrentReuseWithinGraceIsAConflictAndKeepsSessions() throws Exception {
        User user = persistUser(true);
        Cookie refresh = loginCookies(user)[1];
        assertThat(postJson("/api/v1/auth/refresh", Map.of(), refresh).getResponse().getStatus()).isEqualTo(200);

        MvcResult second = postJson("/api/v1/auth/refresh", Map.of(), refresh);

        assertThat(second.getResponse().getStatus()).isEqualTo(409);
        assertThat(body(second).get("code").asText()).isEqualTo("REFRESH_RACE");
        assertThat(second.getResponse().getHeaders("Set-Cookie")).isEmpty();
        assertThat(refreshTokenCount(user.getId())).isEqualTo(2);
    }

    @Test
    void replayOfRotatedTokenWhoseSuccessorWasNeverUsedReissues() throws Exception {
        User user = persistUser(true);
        Cookie refresh = loginCookies(user)[1];
        Cookie lostSuccessor = cookie(postJson("/api/v1/auth/refresh", Map.of(), refresh).getResponse(), "refresh_token");
        ageUsedAt(refresh);

        MvcResult retry = postJson("/api/v1/auth/refresh", Map.of(), refresh);

        assertThat(retry.getResponse().getStatus()).isEqualTo(200);
        Cookie reissued = cookie(retry.getResponse(), "refresh_token");
        assertThat(reissued.getValue()).isNotEqualTo(lostSuccessor.getValue());
        // The never-delivered successor is gone, the re-issued one works
        assertThat(postJson("/api/v1/auth/refresh", Map.of(), lostSuccessor).getResponse().getStatus()).isEqualTo(401);
        assertThat(postJson("/api/v1/auth/refresh", Map.of(), reissued).getResponse().getStatus()).isEqualTo(200);
        assertThat(reload(user.getId()).getTokenVersion()).isZero();
    }

    @Test
    void replayAfterTheSuccessorWasUsedRevokesAllSessions() throws Exception {
        User user = persistUser(true);
        Cookie[] first = loginCookies(user);
        Cookie[] otherDevice = loginCookies(user);
        Cookie successor = cookie(postJson("/api/v1/auth/refresh", Map.of(), first[1]).getResponse(), "refresh_token");
        assertThat(postJson("/api/v1/auth/refresh", Map.of(), successor).getResponse().getStatus()).isEqualTo(200);
        ageUsedAt(first[1]);

        MvcResult theft = postJson("/api/v1/auth/refresh", Map.of(), first[1]);

        assertThat(theft.getResponse().getStatus()).isEqualTo(401);
        assertThat(body(theft).get("error").asText()).isEqualTo("Refresh token has already been used");
        assertThat(setCookieHeader(theft.getResponse(), "refresh_token")).startsWith("refresh_token=;");
        assertThat(refreshTokenCount(user.getId())).isZero();
        assertThat(reload(user.getId()).getTokenVersion()).isEqualTo(1);
        // Every device is logged out, including access tokens that have not expired yet
        mockMvc.perform(get("/api/v1/users/me").cookie(otherDevice[0])).andExpect(status().isUnauthorized());
        assertThat(postJson("/api/v1/auth/refresh", Map.of(), otherDevice[1]).getResponse().getStatus()).isEqualTo(401);
    }

    @Test
    void expiredRotatedTokenWithUnusedSuccessorIsNotReissued() throws Exception {
        User user = persistUser(true);
        Cookie refresh = loginCookies(user)[1];
        postJson("/api/v1/auth/refresh", Map.of(), refresh);
        ageUsedAt(refresh);
        jdbc.update("UPDATE refresh_tokens SET expires_at = now() - interval '1 second' WHERE token_hash = ?",
                sha256(refresh.getValue()));

        MvcResult result = postJson("/api/v1/auth/refresh", Map.of(), refresh);

        assertThat(result.getResponse().getStatus()).isEqualTo(401);
        assertThat(body(result).get("error").asText()).isEqualTo("Refresh token has expired");
        assertThat(reload(user.getId()).getTokenVersion()).isZero();
    }

    @Test
    void refreshForDeactivatedAccountIsRefused() throws Exception {
        User user = persistUser(true);
        Cookie refresh = loginCookies(user)[1];
        entityManager.flush();
        jdbc.update("UPDATE users SET deleted_at = now() WHERE id = ?", user.getId());
        entityManager.clear();

        MvcResult result = postJson("/api/v1/auth/refresh", Map.of(), refresh);

        assertThat(result.getResponse().getStatus()).isEqualTo(401);
        assertThat(body(result).get("error").asText()).isEqualTo("Account has been deactivated");
    }

    @Test
    void logoutWithoutCookieStillClearsCookies() throws Exception {
        MvcResult result = postJson("/api/v1/auth/logout", Map.of());

        assertThat(result.getResponse().getStatus()).isEqualTo(200);
        assertThat(setCookieHeader(result.getResponse(), "access_token")).contains("Max-Age=0");
    }
}
