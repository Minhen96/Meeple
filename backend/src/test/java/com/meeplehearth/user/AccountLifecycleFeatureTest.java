package com.meeplehearth.user;

import com.meeplehearth.common.event.UserSoftDeletedEvent;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.event.ApplicationEvents;
import org.springframework.test.context.event.RecordApplicationEvents;
import org.springframework.test.web.servlet.MvcResult;

import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Account deletion (C11), the 30-day grace period, reactivation and login afterwards. */
@RecordApplicationEvents
class AccountLifecycleFeatureTest extends AccountFeatureTestBase {

    @Autowired ApplicationEvents events;

    private void deleteWith(UUID userId, Object body, int expectedStatus) throws Exception {
        mvc.perform(delete("/api/v1/users/me").with(as(userId))
                        .contentType("application/json").content(toJson(body)))
                .andExpect(status().is(expectedStatus));
    }

    @Test
    void passwordAccountIsDeletedOnlyWithItsPassword() throws Exception {
        UUID userId = passwordUser();

        mvc.perform(delete("/api/v1/users/me").with(as(userId)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("PASSWORD_REQUIRED"));
        mvc.perform(delete("/api/v1/users/me").with(as(userId))
                        .contentType("application/json").content(toJson(Map.of("password", "wrong-password-1"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_PASSWORD"));
        // Typing DELETE is not enough for an account that has a password
        deleteWith(userId, Map.of("confirm", "DELETE"), 400);
        assertThat(count("SELECT count(*) FROM users WHERE id = ? AND deleted_at IS NULL", userId)).isEqualTo(1);

        MvcResult result = mvc.perform(delete("/api/v1/users/me").with(as(userId))
                        .contentType("application/json").content(toJson(Map.of("password", PASSWORD))))
                .andExpect(status().isNoContent())
                .andReturn();

        assertThat(result.getResponse().getHeaders("Set-Cookie"))
                .anyMatch(c -> c.startsWith("access_token=;") && c.contains("Max-Age=0"))
                .anyMatch(c -> c.startsWith("refresh_token=;") && c.contains("Max-Age=0"));
        assertThat(count("SELECT count(*) FROM users WHERE id = ? AND deleted_at IS NOT NULL", userId)).isEqualTo(1);
        assertThat(count("SELECT token_version FROM users WHERE id = ?", userId)).isEqualTo(1);
        assertThat(events.stream(UserSoftDeletedEvent.class)).contains(new UserSoftDeletedEvent(userId));
        // The old access token (version 0) no longer works
        mvc.perform(get("/api/v1/users/me").with(as(userId))).andExpect(status().isUnauthorized());
    }

    @Test
    void googleOnlyAccountConfirmsByTypingDelete() throws Exception {
        UUID userId = googleUser("google-" + UUID.randomUUID());

        deleteWith(userId, Map.of(), 400);
        mvc.perform(delete("/api/v1/users/me").with(as(userId))
                        .contentType("application/json").content(toJson(Map.of("confirm", "delete"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("CONFIRMATION_REQUIRED"));
        mvc.perform(delete("/api/v1/users/me").with(as(userId))
                        .contentType("application/json").content(toJson(Map.of("googleIdToken", "not-a-jwt"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_GOOGLE_TOKEN"));

        deleteWith(userId, Map.of("confirm", "DELETE"), 204);
        assertThat(count("SELECT count(*) FROM users WHERE id = ? AND deleted_at IS NOT NULL", userId)).isEqualTo(1);
    }

    @Test
    void deletionThenReactivationThenLogin() throws Exception {
        UUID userId = passwordUser();
        login(userId, "Mozilla/5.0 (Macintosh) Chrome/120.0");
        deleteWith(userId, Map.of("password", PASSWORD), 204);
        assertThat(count("SELECT count(*) FROM refresh_tokens WHERE user_id = ?", userId)).isZero();

        Map<String, String> credentials = Map.of("emailOrUsername", username(userId), "password", PASSWORD);
        mvc.perform(post("/api/v1/auth/login")
                        .with(req -> { req.setRemoteAddr(freshIp()); return req; })
                        .contentType("application/json").content(toJson(credentials)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("ACCOUNT_DELETED"));

        // A wrong password reveals nothing about the account state
        mvc.perform(post("/api/v1/auth/reactivate")
                        .with(req -> { req.setRemoteAddr(freshIp()); return req; })
                        .contentType("application/json")
                        .content(toJson(Map.of("emailOrUsername", username(userId), "password", "nope-nope-1"))))
                .andExpect(status().isUnauthorized());

        MvcResult reactivated = mvc.perform(post("/api/v1/auth/reactivate")
                        .with(req -> { req.setRemoteAddr(freshIp()); return req; })
                        .contentType("application/json").content(toJson(credentials)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.id").value(userId.toString()))
                .andReturn();
        assertThat(setCookie(reactivated, "access_token")).isNotBlank();
        assertThat(count("SELECT count(*) FROM users WHERE id = ? AND deleted_at IS NULL", userId)).isEqualTo(1);

        login(userId, "Mozilla/5.0 (Macintosh) Chrome/120.0");
    }

    @Test
    void reactivationRules() throws Exception {
        UUID active = passwordUser();
        mvc.perform(post("/api/v1/auth/reactivate")
                        .with(req -> { req.setRemoteAddr(freshIp()); return req; })
                        .contentType("application/json")
                        .content(toJson(Map.of("emailOrUsername", email(active), "password", PASSWORD))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("ACCOUNT_NOT_DELETED"));

        UUID expired = passwordUser();
        jdbc.update("UPDATE users SET deleted_at = ? WHERE id = ?",
                ts(Instant.now().minus(Duration.ofDays(31))), expired);
        Map<String, String> credentials = Map.of("emailOrUsername", username(expired), "password", PASSWORD);
        mvc.perform(post("/api/v1/auth/reactivate")
                        .with(req -> { req.setRemoteAddr(freshIp()); return req; })
                        .contentType("application/json").content(toJson(credentials)))
                .andExpect(status().isUnauthorized());
        // Past the grace period login answers like an unknown account
        mvc.perform(post("/api/v1/auth/login")
                        .with(req -> { req.setRemoteAddr(freshIp()); return req; })
                        .contentType("application/json").content(toJson(credentials)))
                .andExpect(status().isUnauthorized());

        mvc.perform(post("/api/v1/auth/reactivate")
                        .with(req -> { req.setRemoteAddr(freshIp()); return req; })
                        .contentType("application/json").content(toJson(Map.of("emailOrUsername", "someone"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
        mvc.perform(post("/api/v1/auth/reactivate")
                        .with(req -> { req.setRemoteAddr(freshIp()); return req; })
                        .contentType("application/json").content(toJson(Map.of("googleIdToken", "bogus"))))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_GOOGLE_TOKEN"));
    }
}
