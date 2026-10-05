package com.meeplehearth.auth.controller;

import com.meeplehearth.auth.service.GoogleAuthService.GoogleUserInfo;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.support.auth.AuthWebIntegrationTest;
import com.meeplehearth.user.entity.User;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MvcResult;

import java.time.Instant;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Google sign-in through the HTTP layer. Only the ID-token verification (a call to Google) is
 * mocked; account creation, linking and session issuance run against the real database.
 */
class GoogleLoginIntegrationTest extends AuthWebIntegrationTest {

    private MvcResult google(String idToken) throws Exception {
        return mockMvc.perform(post("/api/v1/auth/google").with(fromClientIp())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json(idToken == null ? Map.of() : Map.of("idToken", idToken))))
                .andReturn();
    }

    private void googleSays(String token, String googleId, String email, String name) {
        when(googleAuthService.verify(token)).thenReturn(
                new GoogleUserInfo(googleId, email, name, "https://lh3.example.test/" + googleId + ".png"));
    }

    @Test
    void missingTokenIsRejectedWithoutCallingGoogle() throws Exception {
        for (String token : new String[]{null, "  "}) {
            MvcResult result = google(token);

            assertThat(result.getResponse().getStatus()).isEqualTo(400);
            assertThat(body(result).get("code").asText()).isEqualTo("MISSING_TOKEN");
        }
        verify(googleAuthService, never()).verify(anyString());
    }

    @Test
    void returningGoogleUserWhoFinishedOnboardingIsNotSentBack() throws Exception {
        User existing = persistUser(true);
        existing.setGoogleId("g-" + uniqueName());
        existing.setOnboardingCompleted(true);
        userRepository.saveAndFlush(existing);
        googleSays("returning", existing.getGoogleId(), existing.getEmail(), "Name");

        MvcResult result = google("returning");

        assertThat(result.getResponse().getStatus()).isEqualTo(200);
        assertThat(body(result).at("/data/id").asText()).isEqualTo(existing.getId().toString());
        assertThat(body(result).at("/data/onboardingCompleted").asBoolean()).isTrue();
    }

    @Test
    void tokenGoogleRejectsIsUnauthorized() throws Exception {
        when(googleAuthService.verify("forged"))
                .thenThrow(ApiException.unauthorized("INVALID_GOOGLE_TOKEN", "Invalid Google ID token"));

        MvcResult result = google("forged");

        assertThat(result.getResponse().getStatus()).isEqualTo(401);
        assertThat(body(result).get("code").asText()).isEqualTo("INVALID_GOOGLE_TOKEN");
        assertThat(setCookieValue(result.getResponse(), "access_token")).isNull();
    }

    @Test
    void firstSignInCreatesAVerifiedAccountThatStillNeedsOnboarding() throws Exception {
        String googleId = "g-" + uniqueName();
        String email = trackEmail(uniqueName() + "@Gmail.Example");
        googleSays("new-user", googleId, email, "Ada Lovelace!");

        MvcResult result = google("new-user");

        assertThat(result.getResponse().getStatus()).isEqualTo(200);
        assertThat(body(result).at("/data/onboardingCompleted").asBoolean()).isFalse();
        User created = userRepository.findByGoogleId(googleId).orElseThrow();
        assertThat(created.getEmail()).isEqualTo(email.toLowerCase());
        assertThat(created.isEmailVerified()).isTrue();
        assertThat(created.getPasswordHash()).isNull();
        assertThat(created.getDisplayName()).isEqualTo("Ada Lovelace!");
        assertThat(created.getAvatarUrl()).endsWith(googleId + ".png");
        // Username is derived from the display name: lowercase alphanumerics only
        assertThat(created.getUsername()).startsWith("adalovelace");

        // The issued session works
        String access = setCookieValue(result.getResponse(), "access_token");
        mockMvc.perform(get("/api/v1/users/me").cookie(new jakarta.servlet.http.Cookie("access_token", access)))
                .andExpect(status().isOk());

        // Signing in again finds the same account by Google id
        MvcResult again = google("new-user");
        assertThat(body(again).at("/data/id").asText()).isEqualTo(created.getId().toString());
    }

    @Test
    void generatedUsernamesAreUniqueAndBounded() throws Exception {
        String base = "zq" + uniqueName().substring(1, 9);
        persistUser(base, true, "USER");
        googleSays("collide", "g-" + uniqueName(), trackEmail(uniqueName() + "@example.test"), base.toUpperCase());
        googleSays("short", "g-" + uniqueName(), trackEmail(uniqueName() + "@example.test"), "Zé");
        googleSays("nameless", "g-" + uniqueName(), trackEmail(uniqueName() + "@example.test"), null);
        googleSays("long", "g-" + uniqueName(), trackEmail(uniqueName() + "@example.test"),
                "Supercalifragilisticexpialidocious Person");

        assertThat(body(google("collide")).at("/data/username").asText()).isEqualTo(base + "1");
        assertThat(body(google("short")).at("/data/username").asText()).startsWith("user");
        assertThat(body(google("nameless")).at("/data/username").asText()).startsWith("user");
        assertThat(body(google("long")).at("/data/username").asText()).startsWith("supercalifragilistic")
                .hasSizeLessThanOrEqualTo(22);
    }

    @Test
    void existingVerifiedAccountIsLinkedByEmailAndKeepsItsPassword() throws Exception {
        User existing = persistUser(true);
        String googleId = "g-" + uniqueName();
        googleSays("link", googleId, existing.getEmail().toUpperCase(), "Whoever");

        MvcResult result = google("link");

        assertThat(result.getResponse().getStatus()).isEqualTo(200);
        assertThat(body(result).at("/data/id").asText()).isEqualTo(existing.getId().toString());
        User linked = reload(existing.getId());
        assertThat(linked.getGoogleId()).isEqualTo(googleId);
        assertThat(linked.getTokenVersion()).isZero();
        assertThat(passwordEncoder.matches(PASSWORD, linked.getPasswordHash())).isTrue();
        // Accounts that predate onboarding are not sent through it again
        assertThat(linked.isOnboardingCompleted()).isTrue();
    }

    @Test
    void linkingAnUnverifiedAccountWipesTheSquattersCredentials() throws Exception {
        User squatted = persistUser(false);
        String access = accessToken(squatted);
        googleSays("owner", "g-" + uniqueName(), squatted.getEmail(), "Real Owner");

        MvcResult result = google("owner");

        assertThat(result.getResponse().getStatus()).isEqualTo(200);
        User taken = reload(squatted.getId());
        assertThat(taken.isEmailVerified()).isTrue();
        assertThat(taken.getPasswordHash()).isNull();
        assertThat(taken.getTokenVersion()).isEqualTo(1);
        // The squatter's password and earlier tokens are dead
        mockMvc.perform(get("/api/v1/users/me").header("Authorization", "Bearer " + access))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(post("/api/v1/auth/login").with(fromClientIp()).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("emailOrUsername", squatted.getUsername(), "password", PASSWORD))))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void emailAlreadyLinkedToAnotherGoogleAccountIsAConflict() throws Exception {
        User existing = persistUser(true);
        existing.setGoogleId("g-original-" + uniqueName());
        userRepository.saveAndFlush(existing);
        googleSays("other", "g-other-" + uniqueName(), existing.getEmail(), "Other");

        MvcResult result = google("other");

        assertThat(result.getResponse().getStatus()).isEqualTo(409);
        assertThat(body(result).get("code").asText()).isEqualTo("GOOGLE_ACCOUNT_CONFLICT");
    }

    @Test
    void deletedAccountsCannotSignInWithGoogle() throws Exception {
        User byGoogleId = persistUser(true);
        byGoogleId.setGoogleId("g-" + uniqueName());
        byGoogleId.setDeletedAt(Instant.now());
        userRepository.saveAndFlush(byGoogleId);
        googleSays("deleted-by-id", byGoogleId.getGoogleId(), trackEmail(uniqueName() + "@example.test"), "X");

        User byEmail = persistUser(true);
        byEmail.setDeletedAt(Instant.now());
        userRepository.saveAndFlush(byEmail);
        googleSays("deleted-by-email", "g-" + uniqueName(), byEmail.getEmail(), "Y");

        for (String token : new String[]{"deleted-by-id", "deleted-by-email"}) {
            MvcResult result = google(token);
            assertThat(result.getResponse().getStatus()).as(token).isEqualTo(403);
            assertThat(body(result).get("code").asText()).as(token).isEqualTo("ACCOUNT_DELETED");
        }
        assertThat(reload(byEmail.getId()).getGoogleId()).isNull();
    }
}
