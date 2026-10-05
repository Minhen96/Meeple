package com.meeplehearth.auth;

import com.fasterxml.jackson.databind.JsonNode;
import com.meeplehearth.user.AccountFeatureTestBase;
import jakarta.servlet.http.Cookie;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.MvcResult;

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
}
