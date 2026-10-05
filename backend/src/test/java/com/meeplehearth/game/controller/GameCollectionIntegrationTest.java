package com.meeplehearth.game.controller;

import com.meeplehearth.support.ai.AiGameIntegrationTestBase;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;

import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Collection flags, play logging and the unified activity timeline over HTTP. */
class GameCollectionIntegrationTest extends AiGameIntegrationTestBase {

    private ResultActions upsert(UUID user, UUID gameId, String json) throws Exception {
        return mvc.perform(put("/api/v1/users/me/games/{id}", gameId).cookie(auth(user))
                .contentType(MediaType.APPLICATION_JSON).content(json));
    }

    private ResultActions collection(UUID user, String filter) throws Exception {
        return mvc.perform(get("/api/v1/users/me/games").param("filter", filter).cookie(auth(user)));
    }

    @Test
    void upsertAppliesOnlyProvidedFieldsAndInvalidatesRecommendations() throws Exception {
        UUID user = createUser();
        UUID gameId = game("Collected Game").insert();
        redis.opsForValue().set("rec:" + user, "[\"" + UUID.randomUUID() + "\"]");

        upsert(user, gameId, "{\"isOwned\":true,\"personalRating\":8.5,\"notes\":\"Great with 3\"}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.game.title").value("Collected Game"))
                .andExpect(jsonPath("$.data.personalRating").value(8.5))
                .andExpect(jsonPath("$.data.notes").value("Great with 3"))
                .andExpect(jsonPath("$.data.playCount").value(0));
        assertThat(redis.hasKey("rec:" + user)).isFalse();

        // Partial update: only isFavorited changes
        upsert(user, gameId, "{\"isFavorited\":true}").andExpect(status().isOk());
        assertThat(jdbc.queryForMap("SELECT is_owned, is_favorited, personal_rating, notes FROM user_games "
                + "WHERE user_id = ? AND game_id = ?", user, gameId))
                .containsEntry("is_owned", true).containsEntry("is_favorited", true)
                .containsEntry("notes", "Great with 3");
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM user_games WHERE user_id = ?", Integer.class, user))
                .isEqualTo(1);
    }

    @Test
    void collectionFilters() throws Exception {
        UUID user = createUser();
        UUID owned = game("Owned Only").insert();
        UUID favourite = game("Favourite Only").insert();
        UUID played = game("Played Only").insert();
        upsert(user, owned, "{\"isOwned\":true}").andExpect(status().isOk());
        upsert(user, favourite, "{\"isFavorited\":true}").andExpect(status().isOk());
        mvc.perform(post("/api/v1/users/me/games/{id}/log-play", played).cookie(auth(user))).andExpect(status().isOk());

        collection(user, "owned").andExpect(jsonPath("$.data[*].game.title", contains("Owned Only")));
        collection(user, "favorited").andExpect(jsonPath("$.data[*].game.title", contains("Favourite Only")));
        collection(user, "all").andExpect(jsonPath("$.data", hasSize(3)));
        collection(user, "wishlisted").andExpect(jsonPath("$.data", hasSize(3)));

        // Another user's collection (friends-only is enforced by the frontend)
        UUID viewer = createUser();
        mvc.perform(get("/api/v1/users/{id}/games", user).param("filter", "owned").cookie(auth(viewer)))
                .andExpect(jsonPath("$.data[*].game.title", contains("Owned Only")));
        mvc.perform(get("/api/v1/users/{id}/games", user).cookie(auth(viewer)))
                .andExpect(jsonPath("$.data", hasSize(3)));
    }

    @Test
    void upsertValidationAndMissingGame() throws Exception {
        UUID user = createUser();
        UUID gameId = game("Validated Game").insert();

        upsert(user, gameId, "{\"personalRating\":11}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
        upsert(user, UUID.randomUUID(), "{\"isOwned\":true}")
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("GAME_NOT_FOUND"));
        mvc.perform(post("/api/v1/users/me/games/{id}/log-play", UUID.randomUUID()).cookie(auth(user)))
                .andExpect(status().isNotFound());
    }

    @Test
    void removingFromCollection() throws Exception {
        UUID user = createUser();
        UUID gameId = game("Removable Game").insert();
        upsert(user, gameId, "{\"isOwned\":true}").andExpect(status().isOk());

        mvc.perform(delete("/api/v1/users/me/games/{id}", gameId).cookie(auth(user)))
                .andExpect(status().isNoContent());
        collection(user, "all").andExpect(jsonPath("$.data", hasSize(0)));
        mvc.perform(delete("/api/v1/users/me/games/{id}", gameId).cookie(auth(user)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("COLLECTION_ENTRY_NOT_FOUND"));
    }

    @Test
    void loggingPlaysIncrementsCountAndRecordsHistory() throws Exception {
        UUID user = createUser();
        UUID gameId = game("Played Game").insert();
        upsert(user, gameId, "{\"isOwned\":true}").andExpect(status().isOk());
        redis.opsForValue().set("rec:" + user, "[]");

        mvc.perform(post("/api/v1/users/me/games/{id}/log-play", gameId).cookie(auth(user)))
                .andExpect(jsonPath("$.data.playCount").value(1));
        mvc.perform(post("/api/v1/users/me/games/{id}/log-play", gameId).cookie(auth(user)))
                .andExpect(jsonPath("$.data.playCount").value(2));
        assertThat(redis.hasKey("rec:" + user)).isFalse();

        mvc.perform(get("/api/v1/users/me/games/{id}/plays", gameId).cookie(auth(user)))
                .andExpect(jsonPath("$.data", hasSize(2)))
                .andExpect(jsonPath("$.data[0].playedAt").isNotEmpty());
        assertThat(jdbc.queryForObject("SELECT is_owned FROM user_games WHERE user_id = ? AND game_id = ?",
                Boolean.class, user, gameId)).isTrue();
    }

    @Test
    void activityMergesPlaysAcceptedEventsAndPostsNewestFirst() throws Exception {
        UUID user = createUser();
        UUID host = createUser();
        UUID gameId = game("Timeline Game").insert();
        Instant now = Instant.now();

        jdbc.update("INSERT INTO play_logs (user_id, game_id, played_at) VALUES (?, ?, ?)",
                user, gameId, Timestamp.from(now.minus(Duration.ofDays(3))));
        UUID event = UUID.randomUUID();
        jdbc.update("INSERT INTO events (id, host_id, game_id, title, location, scheduled_at, created_at) "
                        + "VALUES (?, ?, ?, 'Game night', 'Cafe', ?, ?)",
                event, host, gameId, Timestamp.from(now.plus(Duration.ofDays(2))), Timestamp.from(now.minus(Duration.ofDays(2))));
        jdbc.update("INSERT INTO event_participants (event_id, user_id, status) VALUES (?, ?, 'ACCEPTED')", event, user);
        UUID deletedEvent = UUID.randomUUID();
        jdbc.update("INSERT INTO events (id, host_id, title, scheduled_at, deleted_at) VALUES (?, ?, 'Gone', now(), now())",
                deletedEvent, host);
        jdbc.update("INSERT INTO event_participants (event_id, user_id, status) VALUES (?, ?, 'ACCEPTED')",
                deletedEvent, user);
        UUID post = UUID.randomUUID();
        jdbc.update("INSERT INTO posts (id, author_id, caption, location, created_at) VALUES (?, ?, 'Fun!', 'Home', ?)",
                post, user, Timestamp.from(now.minus(Duration.ofDays(1))));
        jdbc.update("INSERT INTO post_images (post_id, url, display_order) VALUES (?, 'https://img/1.jpg', 0)", post);

        mvc.perform(get("/api/v1/users/me/plays").cookie(auth(user)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[*].type", contains("post", "event", "play")))
                .andExpect(jsonPath("$.data[0].caption").value("Fun!"))
                .andExpect(jsonPath("$.data[0].imageUrls[0]").value("https://img/1.jpg"))
                .andExpect(jsonPath("$.data[0].game").doesNotExist())
                .andExpect(jsonPath("$.data[1].eventTitle").value("Game night"))
                .andExpect(jsonPath("$.data[1].eventId").value(event.toString()))
                .andExpect(jsonPath("$.data[1].location").value("Cafe"))
                .andExpect(jsonPath("$.data[1].game.title").value("Timeline Game"))
                .andExpect(jsonPath("$.data[2].game.title").value("Timeline Game"));

        mvc.perform(get("/api/v1/users/{id}/plays", user).cookie(auth(host)))
                .andExpect(jsonPath("$.data", hasSize(3)));
    }
}
