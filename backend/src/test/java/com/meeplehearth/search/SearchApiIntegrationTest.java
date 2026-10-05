package com.meeplehearth.search;

import com.fasterxml.jackson.databind.JsonNode;
import com.meeplehearth.support.social.ApiIntegrationTestBase;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Unified search overlay endpoint: games, players and visible events, limit per category. */
class SearchApiIntegrationTest extends ApiIntegrationTestBase {

    @Test
    void searchReturnsGamesUsersAndVisibleEventsUpToTheLimitEach() throws Exception {
        String word = "qx" + UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        UUID me = user();
        UUID host = user();
        UUID player = user();
        jdbc.update("UPDATE users SET display_name = ? WHERE id = ?", "Player " + word, player);
        UUID gameId = namedGame("Catan " + word);
        UUID upcoming = event(host, word + " upcoming", "PUBLIC", Instant.now().plus(2, ChronoUnit.DAYS), gameId);
        UUID past = event(host, word + " past", "PUBLIC", Instant.now().minus(2, ChronoUnit.DAYS), null);
        event(host, word + " secret", "INVITE_ONLY", Instant.now().plus(1, ChronoUnit.DAYS), null);
        UUID cancelled = event(host, word + " cancelled", "PUBLIC", Instant.now().plus(1, ChronoUnit.DAYS), null);
        jdbc.update("UPDATE events SET status = 'CANCELLED' WHERE id = ?", cancelled);

        JsonNode data = search(me, "  " + word.toUpperCase() + " ", "3", "all");

        assertThat(data.get("games")).extracting(n -> n.get("id").asText()).contains(gameId.toString());
        assertThat(data.get("users")).extracting(n -> n.get("id").asText()).containsExactly(player.toString());
        assertThat(data.get("users").get(0).get("friendshipStatus").asText()).isEqualTo("none");
        assertThat(data.get("events")).extracting(n -> n.get("id").asText())
                .containsExactly(upcoming.toString(), past.toString());
        JsonNode first = data.get("events").get(0);
        assertThat(first.get("game").get("title").asText()).isEqualTo("Catan " + word);
        assertThat(first.has("location")).isFalse();
        assertThat(first.get("status").asText()).isEqualTo("OPEN");

        JsonNode limited = search(me, word, "1", "events");
        assertThat(limited.get("events")).hasSize(1);
        assertThat(limited.get("games")).isEmpty();
        assertThat(limited.get("users")).isEmpty();

        JsonNode usersOnly = search(me, word, "3", "USERS");
        assertThat(usersOnly.get("users")).hasSize(1);
        assertThat(usersOnly.get("events")).isEmpty();
        assertThat(search(me, word, "3", "games").get("games")).isNotEmpty();
    }

    @Test
    void blankQueryIsEmptyAndUnknownTypeIs400() throws Exception {
        UUID me = user();
        JsonNode empty = search(me, "   ", "3", "all");
        assertThat(empty.get("games")).isEmpty();
        assertThat(empty.get("users")).isEmpty();
        assertThat(empty.get("events")).isEmpty();

        mvc.perform(get("/api/v1/search").param("q", "x").param("type", "posts").with(as(me)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_SEARCH_TYPE"));
        mvc.perform(get("/api/v1/search").param("q", "x")).andExpect(status().isUnauthorized());
    }

    @Test
    void overlongQueriesAreTruncatedNotRejected() throws Exception {
        UUID me = user();
        JsonNode data = search(me, "y".repeat(500), "50", "users");
        assertThat(data.get("users")).isEmpty();
    }

    private JsonNode search(UUID viewer, String q, String limit, String type) throws Exception {
        return json(mvc.perform(get("/api/v1/search").param("q", q).param("limit", limit).param("type", type)
                        .with(as(viewer)))
                .andExpect(status().isOk()).andReturn()).get("data");
    }

    private UUID namedGame(String name) {
        UUID id = game();
        jdbc.update("UPDATE games SET name_en = ?, bgg_id = ? WHERE id = ?", name,
                -ThreadLocalRandom.current().nextLong(1_000_000L, Long.MAX_VALUE / 2), id);
        return id;
    }

    private UUID event(UUID host, String title, String visibility, Instant at, UUID gameId) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO events (id, host_id, title, scheduled_at, visibility, status, game_id)"
                + " VALUES (?, ?, ?, ?, ?, 'OPEN', ?)", id, host, title, ts(at), visibility, gameId);
        return id;
    }
}
