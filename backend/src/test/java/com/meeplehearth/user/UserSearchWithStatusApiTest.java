package com.meeplehearth.user;

import com.fasterxml.jackson.databind.JsonNode;
import com.meeplehearth.support.social.ApiIntegrationTestBase;
import org.junit.jupiter.api.Test;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * {@code GET /users/search} and {@code /users/suggestions} return {@code UserSummaryWithStatus}
 * rows (FEATURES_COMPLETE 2.3) in the {@code {data, meta}} page shape mobile already parses.
 */
class UserSearchWithStatusApiTest extends ApiIntegrationTestBase {

    private UUID named(String username) {
        UUID id = user();
        jdbc.update("UPDATE users SET username = ? WHERE id = ?", username, id);
        return id;
    }

    @Test
    void searchCarriesFriendshipStatusAndHidesBlockedUsers() throws Exception {
        String marker = "ss" + UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        UUID me = named(marker + "me");
        UUID friend = named(marker + "fr");
        UUID sent = named(marker + "se");
        UUID received = named(marker + "re");
        UUID stranger = named(marker + "st");
        UUID blocker = named(marker + "bl");
        friends(me, friend);
        jdbc.update("INSERT INTO friend_requests (sender_id, receiver_id, status) VALUES (?, ?, 'PENDING')", me, sent);
        jdbc.update("INSERT INTO friend_requests (sender_id, receiver_id, status) VALUES (?, ?, 'PENDING')", received, me);
        block(blocker, me);

        JsonNode page = json(mvc.perform(get("/api/v1/users/search").param("q", marker).param("limit", "20").with(as(me)))
                .andExpect(status().isOk()).andReturn());

        Map<String, String> statuses = new HashMap<>();
        page.get("data").forEach(n -> statuses.put(n.get("id").asText(), n.get("friendshipStatus").asText()));
        assertThat(statuses).containsOnly(
                Map.entry(friend.toString(), "friends"),
                Map.entry(sent.toString(), "pending_sent"),
                Map.entry(received.toString(), "pending_received"),
                Map.entry(stranger.toString(), "none"));
        JsonNode row = page.get("data").get(0);
        assertThat(row.has("username")).isTrue();
        assertThat(row.has("displayName")).isTrue();
        assertThat(row.has("avatarUrl")).isTrue();
        assertThat(page.get("meta").get("total").asInt()).isEqualTo(4);
    }

    @Test
    void suggestionsPreferGameOverlapAndHonourLimit() throws Exception {
        UUID me = user();
        UUID overlap = user();
        UUID game = game();
        jdbc.update("INSERT INTO user_games (user_id, game_id, is_owned) VALUES (?, ?, true)", me, game);
        jdbc.update("INSERT INTO user_games (user_id, game_id, is_owned) VALUES (?, ?, true)", overlap, game);

        JsonNode page = json(mvc.perform(get("/api/v1/users/suggestions").param("limit", "1").with(as(me)))
                .andExpect(status().isOk()).andReturn());

        assertThat(page.get("data")).hasSize(1);
        assertThat(page.get("data").get(0).get("id").asText()).isEqualTo(overlap.toString());
        assertThat(page.get("data").get(0).get("friendshipStatus").asText()).isEqualTo("none");
        assertThat(page.get("meta").get("hasMore").asBoolean()).isFalse();
    }
}
