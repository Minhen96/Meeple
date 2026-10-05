package com.meeplehearth.user;

import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.nullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Profiles: block-aware 404, private fields, validation (C12), username cooldown, language. */
class ProfileFeatureTest extends AccountFeatureTestBase {

    @Test
    void profileIsHiddenWhenEitherUserBlockedTheOther() throws Exception {
        UUID viewer = user();
        UUID blocker = user();
        UUID blockedByViewer = user();
        UUID stranger = user();
        block(blocker, viewer);
        block(viewer, blockedByViewer);

        mvc.perform(get("/api/v1/users/" + blocker).with(as(viewer)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("USER_NOT_FOUND"));
        mvc.perform(get("/api/v1/users/" + blockedByViewer).with(as(viewer)))
                .andExpect(status().isNotFound());
        mvc.perform(get("/api/v1/users/" + stranger).with(as(viewer)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.id").value(stranger.toString()))
                .andExpect(jsonPath("$.data.isVerified").value(false))
                .andExpect(jsonPath("$.data.email").value(nullValue()))
                .andExpect(jsonPath("$.data.preferredLanguage").value(nullValue()));

        softDeleteUser(stranger);
        mvc.perform(get("/api/v1/users/" + stranger).with(as(viewer))).andExpect(status().isNotFound());
    }

    @Test
    void ownProfileIncludesAccountSettings() throws Exception {
        UUID me = passwordUser();
        mvc.perform(get("/api/v1/users/me").with(as(me)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.email").value(email(me)))
                .andExpect(jsonPath("$.data.hasPassword").value(true))
                .andExpect(jsonPath("$.data.googleLinked").value(false))
                .andExpect(jsonPath("$.data.preferredLanguage").value("en"))
                .andExpect(jsonPath("$.data.usernameChangeAvailableAt").value(nullValue()));
        // Viewing yourself by id gives the same private view
        mvc.perform(get("/api/v1/users/" + me).with(as(me)))
                .andExpect(jsonPath("$.data.email").value(email(me)));
    }

    @Test
    void updateValidatesFieldsAndStoresLanguageAndTimezone() throws Exception {
        UUID me = user();
        putMe(me, Map.of("displayName", "   "), 400);
        putMe(me, Map.of("displayName", "x".repeat(51)), 400);
        putMe(me, Map.of("bio", "b".repeat(201)), 400);
        putMe(me, Map.of("preferredLanguage", "fr"), 400);
        mvc.perform(put("/api/v1/users/me").with(as(me)).contentType("application/json")
                        .content(toJson(Map.of("timezone", "Mars/Olympus"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_TIMEZONE"));

        mvc.perform(put("/api/v1/users/me").with(as(me)).contentType("application/json")
                        .content(toJson(Map.of("displayName", "  Ana  ", "bio", "b".repeat(200),
                                "preferredLanguage", "zh-CN", "timezone", "Asia/Kuala_Lumpur"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.displayName").value("Ana"))
                .andExpect(jsonPath("$.data.preferredLanguage").value("zh-CN"))
                .andExpect(jsonPath("$.data.timezone").value("Asia/Kuala_Lumpur"));
        assertThat(string("SELECT preferred_language FROM users WHERE id = ?", me)).isEqualTo("zh-CN");
    }

    @Test
    void usernameCanChangeOncePerThirtyDays() throws Exception {
        UUID me = user();
        UUID other = user();
        String fresh = "wp5_" + UUID.randomUUID().toString().replace("-", "").substring(0, 12);

        mvc.perform(put("/api/v1/users/me").with(as(me)).contentType("application/json")
                        .content(toJson(Map.of("username", username(other)))))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("USERNAME_TAKEN"));
        putMe(me, Map.of("username", "Bad Name"), 400);

        mvc.perform(put("/api/v1/users/me").with(as(me)).contentType("application/json")
                        .content(toJson(Map.of("username", fresh))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.username").value(fresh))
                .andExpect(jsonPath("$.data.usernameChangeAvailableAt").isNotEmpty());

        // Same username again is a no-op, not a change
        putMe(me, Map.of("username", fresh), 200);
        mvc.perform(put("/api/v1/users/me").with(as(me)).contentType("application/json")
                        .content(toJson(Map.of("username", fresh + "x"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("USERNAME_CHANGE_TOO_SOON"));

        jdbc.update("UPDATE users SET username_changed_at = ? WHERE id = ?",
                ts(Instant.now().minus(Duration.ofDays(31))), me);
        putMe(me, Map.of("username", fresh + "x"), 200);
    }

    private void putMe(UUID userId, Map<String, ?> body, int expectedStatus) throws Exception {
        mvc.perform(put("/api/v1/users/me").with(as(userId)).contentType("application/json").content(toJson(body)))
                .andExpect(status().is(expectedStatus));
    }
}
