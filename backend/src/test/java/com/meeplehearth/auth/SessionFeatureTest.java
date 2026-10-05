package com.meeplehearth.auth;

import com.fasterxml.jackson.databind.JsonNode;
import com.meeplehearth.auth.util.TokenHashing;
import com.meeplehearth.user.AccountFeatureTestBase;
import jakarta.servlet.http.Cookie;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.MvcResult;

import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Active sessions: list with device and current marker, revoke one, revoke all others. */
class SessionFeatureTest extends AccountFeatureTestBase {

    private static final String MAC_CHROME =
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0 Safari/537.36";
    private static final String IPHONE_SAFARI =
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Version/17.0 Mobile Safari/604.1";

    private JsonNode sessions(Cookie[] cookies) throws Exception {
        return json(mvc.perform(get("/api/v1/auth/sessions").cookie(cookies))
                .andExpect(status().isOk())
                .andReturn()).get("data");
    }

    @Test
    void listsSessionsAndRevokesAnotherDevice() throws Exception {
        UUID userId = passwordUser();
        Cookie[] laptop = sessionCookies(login(userId, MAC_CHROME));
        login(userId, IPHONE_SAFARI);

        JsonNode list = sessions(laptop);
        assertThat(list).hasSize(2);
        JsonNode current = null;
        JsonNode phone = null;
        for (JsonNode s : list) {
            if (s.get("current").asBoolean()) current = s; else phone = s;
        }
        assertThat(current).isNotNull();
        assertThat(current.get("deviceInfo").asText()).isEqualTo("Chrome on macOS");
        assertThat(phone.get("deviceInfo").asText()).isEqualTo("Safari on iOS");
        assertThat(phone.get("createdAt").asText()).isNotBlank();
        assertThat(phone.get("lastUsedAt").asText()).isNotBlank();

        mvc.perform(delete("/api/v1/auth/sessions/" + current.get("id").asText()).cookie(laptop))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("CANNOT_REVOKE_CURRENT_SESSION"));
        mvc.perform(delete("/api/v1/auth/sessions/" + phone.get("id").asText()).cookie(laptop))
                .andExpect(status().isNoContent());
        assertThat(sessions(laptop)).hasSize(1);

        // Someone else's session id is simply not found
        UUID other = passwordUser();
        Cookie[] otherCookies = sessionCookies(login(other, MAC_CHROME));
        mvc.perform(delete("/api/v1/auth/sessions/" + current.get("id").asText()).cookie(otherCookies))
                .andExpect(status().isNotFound());
    }

    @Test
    void revokeOthersKeepsThisDeviceSignedIn() throws Exception {
        UUID userId = passwordUser();
        Cookie[] laptop = sessionCookies(login(userId, MAC_CHROME));
        Cookie[] phone = sessionCookies(login(userId, IPHONE_SAFARI));

        MvcResult result = mvc.perform(post("/api/v1/auth/sessions/revoke-others").cookie(laptop))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.revoked").value(1))
                .andReturn();

        assertThat(count("SELECT token_version FROM users WHERE id = ?", userId)).isEqualTo(1);
        // The phone's access token died with the version bump, its refresh token is gone
        mvc.perform(get("/api/v1/users/me").cookie(phone[0])).andExpect(status().isUnauthorized());
        mvc.perform(post("/api/v1/auth/refresh").cookie(phone[1])).andExpect(status().isUnauthorized());

        // This device got a fresh access cookie and keeps its refresh token
        String freshAccess = setCookie(result, "access_token");
        assertThat(freshAccess).isNotBlank();
        Cookie[] updated = {new Cookie("access_token", freshAccess), laptop[1]};
        assertThat(sessions(updated)).hasSize(1);
    }

    @Test
    void rotationKeepsTheSessionStartAndDevice() throws Exception {
        UUID userId = passwordUser();
        Cookie[] laptop = sessionCookies(login(userId, MAC_CHROME));
        String startedBefore = sessions(laptop).get(0).get("createdAt").asText();

        MvcResult refreshed = mvc.perform(post("/api/v1/auth/refresh").cookie(laptop[1]))
                .andExpect(status().isOk())
                .andReturn();
        Cookie[] rotated = sessionCookies(refreshed);
        JsonNode after = sessions(rotated);
        assertThat(after).hasSize(1);
        assertThat(after.get(0).get("createdAt").asText()).isEqualTo(startedBefore);
        assertThat(after.get(0).get("deviceInfo").asText()).isEqualTo("Chrome on macOS");
        assertThat(after.get(0).get("current").asBoolean()).isTrue();
    }

    @Test
    void sessionEndpointsRequireAuthentication() throws Exception {
        mvc.perform(get("/api/v1/auth/sessions")).andExpect(status().isUnauthorized());
        mvc.perform(post("/api/v1/auth/sessions/revoke-others")).andExpect(status().isUnauthorized());
        UUID userId = user();
        // Without a refresh cookie this device's session cannot be identified
        mvc.perform(post("/api/v1/auth/sessions/revoke-others").with(as(userId)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("CURRENT_SESSION_UNKNOWN"));
    }

    private String family(String rawRefresh) {
        return string("SELECT family_id::text FROM refresh_tokens WHERE token_hash = ?", TokenHashing.sha256Hex(rawRefresh));
    }

    private void registerPush(Cookie[] cookies, String token) throws Exception {
        mvc.perform(post("/api/v1/users/me/fcm-tokens").cookie(cookies)
                        .contentType("application/json")
                        .content(toJson(Map.of("token", token, "platform", "ios"))))
                .andExpect(status().isNoContent());
    }

    private Cookie[] refresh(Cookie refreshCookie) throws Exception {
        return sessionCookies(mvc.perform(post("/api/v1/auth/refresh").cookie(refreshCookie))
                .andExpect(status().isOk()).andReturn());
    }

    @Test
    void sessionIdIsTheFamilyAndStaysStableAcrossRefresh() throws Exception {
        UUID userId = passwordUser();
        Cookie[] laptop = sessionCookies(login(userId, MAC_CHROME));
        Cookie[] phone = sessionCookies(login(userId, IPHONE_SAFARI));
        String phoneSession = null;
        for (JsonNode s : sessions(laptop)) {
            if (!s.get("current").asBoolean()) phoneSession = s.get("id").asText();
        }
        assertThat(phoneSession).isEqualTo(family(phone[1].getValue()));

        // The phone refreshes twice: its session id does not change
        Cookie[] phone3 = refresh(refresh(phone[1])[1]);
        JsonNode list = sessions(laptop);
        assertThat(list).hasSize(2);
        assertThat(list.findValuesAsText("id")).contains(phoneSession);
        assertThat(count("SELECT COUNT(*) FROM refresh_tokens WHERE family_id = ?::uuid", phoneSession)).isEqualTo(3);

        // Revoking with the id seen before the refreshes removes the whole family, nothing else
        mvc.perform(delete("/api/v1/auth/sessions/" + phoneSession).cookie(laptop))
                .andExpect(status().isNoContent());
        assertThat(count("SELECT COUNT(*) FROM refresh_tokens WHERE family_id = ?::uuid", phoneSession)).isZero();
        mvc.perform(post("/api/v1/auth/refresh").cookie(phone3[1])).andExpect(status().isUnauthorized());
        assertThat(count("SELECT token_version FROM users WHERE id = ?", userId)).isZero();
        assertThat(sessions(laptop)).hasSize(1);

        // Revoked, unknown and foreign ids are 404
        mvc.perform(delete("/api/v1/auth/sessions/" + phoneSession).cookie(laptop))
                .andExpect(status().isNotFound());
        mvc.perform(delete("/api/v1/auth/sessions/" + UUID.randomUUID()).cookie(laptop))
                .andExpect(status().isNotFound());
    }

    @Test
    void currentSessionCannotBeRevokedByItsFamilyIdAfterRefresh() throws Exception {
        UUID userId = passwordUser();
        Cookie[] laptop = sessionCookies(login(userId, MAC_CHROME));
        String id = sessions(laptop).get(0).get("id").asText();
        Cookie[] refreshed = refresh(laptop[1]);
        mvc.perform(delete("/api/v1/auth/sessions/" + id).cookie(refreshed))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("CANNOT_REVOKE_CURRENT_SESSION"));
    }

    @Test
    void revokeOthersRequiresALiveRefreshTokenOfThisUser() throws Exception {
        UUID userId = passwordUser();
        Cookie[] laptop = sessionCookies(login(userId, MAC_CHROME));
        Cookie[] phone = sessionCookies(login(userId, IPHONE_SAFARI));

        // A bogus cookie signs nobody out
        mvc.perform(post("/api/v1/auth/sessions/revoke-others")
                        .cookie(laptop[0], new Cookie("refresh_token", "not-a-real-token")))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("SESSION_INVALID"));
        // Nor does another user's live token
        UUID other = passwordUser();
        Cookie[] otherCookies = sessionCookies(login(other, MAC_CHROME));
        mvc.perform(post("/api/v1/auth/sessions/revoke-others").cookie(laptop[0], otherCookies[1]))
                .andExpect(status().isUnauthorized());
        // Nor a rotated (used) token of this user
        Cookie[] laptop2 = refresh(laptop[1]);
        mvc.perform(post("/api/v1/auth/sessions/revoke-others").cookie(laptop2[0], laptop[1]))
                .andExpect(status().isUnauthorized());

        assertThat(count("SELECT token_version FROM users WHERE id = ?", userId)).isZero();
        assertThat(sessions(laptop2)).hasSize(2);
        mvc.perform(post("/api/v1/auth/refresh").cookie(phone[1])).andExpect(status().isOk());
    }

    @Test
    void revokingSessionsRemovesTheirPushRegistrations() throws Exception {
        UUID userId = passwordUser();
        Cookie[] laptop = sessionCookies(login(userId, MAC_CHROME));
        Cookie[] phone = sessionCookies(login(userId, IPHONE_SAFARI));
        Cookie[] tablet = sessionCookies(login(userId, IPHONE_SAFARI));
        registerPush(laptop, "fcm-laptop-" + userId);
        registerPush(phone, "fcm-phone-" + userId);
        registerPush(tablet, "fcm-tablet-" + userId);
        // Registered without a refresh cookie: the session is unknown
        registerPush(new Cookie[]{laptop[0]}, "fcm-unknown-" + userId);
        assertThat(string("SELECT family_id::text FROM user_fcm_tokens WHERE fcm_token = ?", "fcm-phone-" + userId))
                .isEqualTo(family(phone[1].getValue()));
        assertThat(string("SELECT family_id::text FROM user_fcm_tokens WHERE fcm_token = ?", "fcm-unknown-" + userId))
                .isNull();

        mvc.perform(delete("/api/v1/auth/sessions/" + family(phone[1].getValue())).cookie(laptop))
                .andExpect(status().isNoContent());
        assertThat(count("SELECT COUNT(*) FROM user_fcm_tokens WHERE user_id = ?", userId)).isEqualTo(3);
        assertThat(count("SELECT COUNT(*) FROM user_fcm_tokens WHERE fcm_token = ?", "fcm-phone-" + userId)).isZero();

        mvc.perform(post("/api/v1/auth/sessions/revoke-others").cookie(laptop))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.revoked").value(1));
        assertThat(jdbc.queryForList("SELECT fcm_token FROM user_fcm_tokens WHERE user_id = ?", String.class, userId))
                .containsExactly("fcm-laptop-" + userId);
    }

    @Test
    void reuseOfARotatedTokenStillRevokesEverySession() throws Exception {
        UUID userId = passwordUser();
        Cookie[] laptop = sessionCookies(login(userId, MAC_CHROME));
        login(userId, IPHONE_SAFARI);
        refresh(refresh(laptop[1])[1]);
        jdbc.update("UPDATE refresh_tokens SET used_at = now() - interval '1 hour'"
                + " WHERE user_id = ? AND used_at IS NOT NULL", userId);

        // The first token was rotated and its successor used: theft, every session is revoked
        mvc.perform(post("/api/v1/auth/refresh").cookie(laptop[1])).andExpect(status().isUnauthorized());
        assertThat(count("SELECT COUNT(*) FROM refresh_tokens WHERE user_id = ?", userId)).isZero();
    }
}
