package com.meeplehearth.user.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.meeplehearth.support.auth.AuthWebIntegrationTest;
import com.meeplehearth.user.entity.User;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MvcResult;

import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** /api/v1/users and /api/v1/admin/users through the HTTP layer against the real database. */
class UserControllerIntegrationTest extends AuthWebIntegrationTest {

    private static List<String> ids(JsonNode page) {
        List<String> ids = new ArrayList<>();
        page.get("data").forEach(u -> ids.add(u.get("id").asText()));
        return ids;
    }

    // ------------------------------------------------------------------ /me

    @Test
    void getMeReturnsTheCallersProfile() throws Exception {
        User me = persistUser(true);

        mockMvc.perform(get("/api/v1/users/me").cookie(accessCookie(me)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.id").value(me.getId().toString()))
                .andExpect(jsonPath("$.data.username").value(me.getUsername()))
                .andExpect(jsonPath("$.data.displayName").value(me.getDisplayName()))
                .andExpect(jsonPath("$.data.isAdmin").value(false))
                .andExpect(jsonPath("$.data.onboardingCompleted").value(false))
                // The caller sees their own account settings; credentials never leave the server
                .andExpect(jsonPath("$.data.email").value(me.getEmail()))
                .andExpect(jsonPath("$.data.hasPassword").value(true))
                .andExpect(jsonPath("$.data.passwordHash").doesNotExist());
    }

    @Test
    void meRequiresAuthentication() throws Exception {
        mockMvc.perform(get("/api/v1/users/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"))
                .andExpect(jsonPath("$.error").value("Authentication required"));
    }

    @Test
    void updateMeChangesOnlyTheFieldsSent() throws Exception {
        User me = persistUser(true);
        me.setBio("old bio");
        me.setLocation("Kuala Lumpur");
        userRepository.saveAndFlush(me);

        mockMvc.perform(put("/api/v1/users/me").cookie(accessCookie(me))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("displayName", "New Name", "avatarUrl", "https://cdn.example.test/a.png",
                                "onboardingCompleted", true))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.displayName").value("New Name"))
                .andExpect(jsonPath("$.data.bio").value("old bio"))
                .andExpect(jsonPath("$.data.location").value("Kuala Lumpur"))
                .andExpect(jsonPath("$.data.avatarUrl").value("https://cdn.example.test/a.png"))
                .andExpect(jsonPath("$.data.onboardingCompleted").value(true));

        mockMvc.perform(put("/api/v1/users/me").cookie(accessCookie(me))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("bio", "new bio", "location", "Penang", "onboardingCompleted", false))))
                .andExpect(status().isOk());

        User updated = reload(me.getId());
        assertThat(updated.getDisplayName()).isEqualTo("New Name");
        assertThat(updated.getBio()).isEqualTo("new bio");
        assertThat(updated.getLocation()).isEqualTo("Penang");
        // Onboarding can be completed but never un-completed
        assertThat(updated.isOnboardingCompleted()).isTrue();
    }

    @Test
    void updateMeValidatesFieldLengths() throws Exception {
        User me = persistUser(true);
        Map<String, Object> body = new HashMap<>();
        body.put("displayName", "");
        body.put("bio", "b".repeat(201));

        MvcResult result = mockMvc.perform(put("/api/v1/users/me").cookie(accessCookie(me))
                        .contentType(MediaType.APPLICATION_JSON).content(json(body)))
                .andReturn();

        assertThat(result.getResponse().getStatus()).isEqualTo(400);
        assertThat(body(result).get("code").asText()).isEqualTo("VALIDATION_ERROR");
        assertThat(body(result).get("error").asText()).contains("displayName").contains("bio");
        assertThat(reload(me.getId()).getDisplayName()).isEqualTo(me.getDisplayName());
    }

    @Test
    void deleteMeSoftDeletesAndEndsEverySession() throws Exception {
        User me = persistUser(true);
        jdbc.update("INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES (?, ?, now() + interval '1 day')",
                me.getId(), sha256("refresh-" + me.getId()));

        mockMvc.perform(delete("/api/v1/users/me").cookie(accessCookie(me))
                        .contentType(MediaType.APPLICATION_JSON).content(json(Map.of("password", PASSWORD))))
                .andExpect(status().isNoContent());

        User deleted = reload(me.getId());
        assertThat(deleted.getDeletedAt()).isNotNull().isBeforeOrEqualTo(Instant.now());
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM refresh_tokens WHERE user_id = ?", Integer.class, me.getId()))
                .isZero();
        // The still-unexpired access token no longer authenticates, and the profile is gone
        mockMvc.perform(get("/api/v1/users/me").cookie(accessCookie(deleted))).andExpect(status().isUnauthorized());
        User other = persistUser(true);
        mockMvc.perform(get("/api/v1/users/" + me.getId()).cookie(accessCookie(other)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("USER_NOT_FOUND"));
    }

    // ------------------------------------------------------------------ other users

    @Test
    void publicProfileOfAnotherUser() throws Exception {
        User me = persistUser(true);
        User other = persistUser(true);

        mockMvc.perform(get("/api/v1/users/" + other.getId()).cookie(accessCookie(me)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.username").value(other.getUsername()));
        mockMvc.perform(get("/api/v1/users/" + UUID.randomUUID()).cookie(accessCookie(me)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("USER_NOT_FOUND"));
    }

    @Test
    void searchMatchesUsernameOrDisplayNameAndSkipsDeletedUsers() throws Exception {
        String marker = "srch" + uniqueName().substring(1, 9);
        User me = persistUser(true);
        User byUsername = persistUser(marker + "a", true, "USER");
        User byDisplayName = persistUser(true);
        byDisplayName.setDisplayName("The " + marker.toUpperCase() + " Player");
        User deleted = persistUser(marker + "z", true, "USER");
        deleted.setDeletedAt(Instant.now());
        userRepository.saveAllAndFlush(List.of(byDisplayName, deleted));

        MvcResult result = mockMvc.perform(get("/api/v1/users/search").cookie(accessCookie(me))
                        .param("q", "  " + marker + " ").param("size", "1"))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode page = body(result);
        assertThat(page.at("/meta/total").asLong()).isEqualTo(2);
        assertThat(page.at("/meta/page").asInt()).isEqualTo(1);
        assertThat(page.at("/meta/limit").asInt()).isEqualTo(1);
        assertThat(page.at("/meta/hasMore").asBoolean()).isTrue();
        assertThat(page.has("data")).isTrue();

        JsonNode all = body(mockMvc.perform(get("/api/v1/users/search").cookie(accessCookie(me)).param("q", marker))
                .andReturn());
        assertThat(ids(all)).containsExactlyInAnyOrder(byUsername.getId().toString(), byDisplayName.getId().toString());
        assertThat(all.at("/meta/hasMore").asBoolean()).isFalse();
    }

    @Test
    void suggestionsExcludeSelfFriendsAndDeletedUsers() throws Exception {
        User me = persistUser(true);
        User friend = persistUser(true);
        User pendingRequest = persistUser(true);
        User stranger = persistUser(true);
        User deleted = persistUser(true);
        deleted.setDeletedAt(Instant.now());
        userRepository.saveAndFlush(deleted);
        jdbc.update("INSERT INTO friend_requests (sender_id, receiver_id, status) VALUES (?, ?, 'ACCEPTED')",
                friend.getId(), me.getId());
        jdbc.update("INSERT INTO friend_requests (sender_id, receiver_id, status) VALUES (?, ?, 'PENDING')",
                me.getId(), pendingRequest.getId());

        JsonNode page = body(mockMvc.perform(get("/api/v1/users/suggestions").cookie(accessCookie(me))
                        .param("size", "200"))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(ids(page))
                .contains(stranger.getId().toString(), pendingRequest.getId().toString())
                .doesNotContain(me.getId().toString(), friend.getId().toString(), deleted.getId().toString());
    }

    // ------------------------------------------------------------------ admin

    @Test
    void onlyAdminsCanPromoteUsers() throws Exception {
        User admin = persistAdmin();
        User user = persistUser(true);
        User target = persistUser(true);
        String path = "/api/v1/admin/users/" + target.getId() + "/promote";

        mockMvc.perform(post(path)).andExpect(status().isUnauthorized());
        mockMvc.perform(post(path).cookie(accessCookie(user))).andExpect(status().isForbidden());
        assertThat(reload(target.getId()).getRole()).isEqualTo("USER");

        mockMvc.perform(post(path).cookie(accessCookie(admin))).andExpect(status().isNoContent());
        assertThat(reload(target.getId()).getRole()).isEqualTo("ADMIN");
        mockMvc.perform(get("/api/v1/users/me").cookie(accessCookie(target)))
                .andExpect(jsonPath("$.data.isAdmin").value(true));

        mockMvc.perform(post(path).cookie(accessCookie(admin)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("ALREADY_ADMIN"));
        mockMvc.perform(post("/api/v1/admin/users/" + UUID.randomUUID() + "/promote").cookie(accessCookie(admin)))
                .andExpect(status().isNotFound());
        User deleted = persistUser(true);
        deleted.setDeletedAt(Instant.now());
        userRepository.saveAndFlush(deleted);
        mockMvc.perform(post("/api/v1/admin/users/" + deleted.getId() + "/promote").cookie(accessCookie(admin)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("USER_NOT_FOUND"));
    }
}
