package com.meeplehearth.user;

import com.meeplehearth.user.service.AccountMailer;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Change email: password-confirmed request, link to the new address, confirmation. */
class EmailChangeFeatureTest extends AccountFeatureTestBase {

    @MockitoBean AccountMailer mailer;

    private String requestChange(UUID userId, String newEmail) throws Exception {
        mvc.perform(post("/api/v1/users/me/change-email").with(as(userId)).contentType("application/json")
                        .content(toJson(Map.of("currentPassword", PASSWORD, "newEmail", newEmail))))
                .andExpect(status().isOk());
        ArgumentCaptor<String> token = ArgumentCaptor.forClass(String.class);
        verify(mailer, org.mockito.Mockito.atLeastOnce()).sendEmailChangeVerification(
                eq(userId), eq(newEmail.toLowerCase()), token.capture(), anyString(), any(Duration.class));
        verify(mailer, org.mockito.Mockito.atLeastOnce()).sendEmailChangeNotice(eq(userId), anyString(), anyString());
        return token.getValue();
    }

    private static String newAddress() {
        return "wp5-" + UUID.randomUUID().toString().substring(0, 8) + "@Example.test";
    }

    @Test
    void changesEmailAfterConfirmation() throws Exception {
        UUID userId = passwordUser();
        String newEmail = newAddress();
        String token = requestChange(userId, newEmail);
        // Nothing changes until the link is opened
        assertThat(email(userId)).isNotEqualTo(newEmail.toLowerCase());

        mvc.perform(post("/api/v1/auth/confirm-email-change").contentType("application/json")
                        .content(toJson(Map.of("token", token))))
                .andExpect(status().isOk());
        assertThat(email(userId)).isEqualTo(newEmail.toLowerCase());

        mvc.perform(post("/api/v1/auth/confirm-email-change").contentType("application/json")
                        .content(toJson(Map.of("token", token))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("TOKEN_USED"));
    }

    @Test
    void rejectsBadRequests() throws Exception {
        UUID userId = passwordUser();
        UUID other = user();

        mvc.perform(post("/api/v1/users/me/change-email").with(as(userId)).contentType("application/json")
                        .content(toJson(Map.of("currentPassword", "wrong-pass-1", "newEmail", newAddress()))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_PASSWORD"));
        mvc.perform(post("/api/v1/users/me/change-email").with(as(userId)).contentType("application/json")
                        .content(toJson(Map.of("currentPassword", PASSWORD, "newEmail", email(other)))))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("EMAIL_TAKEN"));
        mvc.perform(post("/api/v1/users/me/change-email").with(as(userId)).contentType("application/json")
                        .content(toJson(Map.of("currentPassword", PASSWORD, "newEmail", email(userId)))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("EMAIL_UNCHANGED"));
        mvc.perform(post("/api/v1/users/me/change-email").with(as(userId)).contentType("application/json")
                        .content(toJson(Map.of("currentPassword", PASSWORD, "newEmail", "not-an-email"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));

        UUID google = googleUser("g-" + UUID.randomUUID());
        mvc.perform(post("/api/v1/users/me/change-email").with(as(google)).contentType("application/json")
                        .content(toJson(Map.of("currentPassword", "whatever-1", "newEmail", newAddress()))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("PASSWORD_REQUIRED"));
    }

    @Test
    void confirmationFailures() throws Exception {
        mvc.perform(post("/api/v1/auth/confirm-email-change").contentType("application/json")
                        .content(toJson(Map.of("token", "deadbeef"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_TOKEN"));
        mvc.perform(post("/api/v1/auth/confirm-email-change").contentType("application/json")
                        .content(toJson(Map.of())))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("MISSING_TOKEN"));

        UUID userId = passwordUser();
        String expired = requestChange(userId, newAddress());
        jdbc.update("UPDATE email_change_tokens SET expires_at = ? WHERE user_id = ?",
                ts(Instant.now().minusSeconds(60)), userId);
        mvc.perform(post("/api/v1/auth/confirm-email-change").contentType("application/json")
                        .content(toJson(Map.of("token", expired))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("TOKEN_EXPIRED"));

        // The address was taken by someone else after the request
        UUID racer = passwordUser();
        String wanted = newAddress();
        String token = requestChange(racer, wanted);
        UUID squatter = user();
        jdbc.update("UPDATE users SET email = ? WHERE id = ?", wanted.toLowerCase(), squatter);
        mvc.perform(post("/api/v1/auth/confirm-email-change").contentType("application/json")
                        .content(toJson(Map.of("token", token))))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("EMAIL_TAKEN"));
    }
}
