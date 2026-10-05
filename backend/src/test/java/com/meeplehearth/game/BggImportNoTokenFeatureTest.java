package com.meeplehearth.game;

import com.meeplehearth.support.social.ApiIntegrationTestBase;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Without BGG_API_TOKEN (the default test configuration) the import fails cleanly with 503. */
class BggImportNoTokenFeatureTest extends ApiIntegrationTestBase {

    @Test
    void importReturns503AndRecordsTheFailure() throws Exception {
        UUID user = user();

        mvc.perform(post("/api/v1/users/me/bgg-import").with(as(user))
                        .contentType(MediaType.APPLICATION_JSON).content(toJson(Map.of("bggUsername", "alice"))))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.code").value("BGG_API_UNAVAILABLE"));

        mvc.perform(get("/api/v1/users/me/bgg-import/status").with(as(user)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("failed"))
                .andExpect(jsonPath("$.data.errorCode").value("BGG_API_UNAVAILABLE"));
        // The username is still saved for a later retry from Settings
        assertThat(string("SELECT bgg_username FROM users WHERE id = ?", user)).isEqualTo("alice");
    }
}
