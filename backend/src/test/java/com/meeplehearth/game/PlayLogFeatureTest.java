package com.meeplehearth.game;

import com.fasterxml.jackson.databind.JsonNode;
import com.meeplehearth.common.event.SessionPlayedEvent;
import com.meeplehearth.common.event.UserSoftDeletedEvent;
import com.meeplehearth.support.social.ApiIntegrationTestBase;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.MediaType;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
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

/** Play logging, play deletion, the SessionPlayedEvent listener and account-deletion cleanup. */
class PlayLogFeatureTest extends ApiIntegrationTestBase {

    @Autowired private ApplicationEventPublisher publisher;
    @Autowired private PlatformTransactionManager transactionManager;
    @Autowired private StringRedisTemplate redis;

    private UUID createPost(UUID author, UUID game) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO posts (id, author_id, game_id) VALUES (?, ?, ?)", id, author, game);
        return id;
    }

    /** Publishes inside a committed transaction, like the posts package does. */
    private void publishInTransaction(Object event) {
        new TransactionTemplate(transactionManager).executeWithoutResult(s -> publisher.publishEvent(event));
    }

    private int playCount(UUID user, UUID game) {
        List<Integer> rows = jdbc.queryForList(
                "SELECT play_count FROM user_games WHERE user_id = ? AND game_id = ?", Integer.class, user, game);
        return rows.isEmpty() ? -1 : rows.get(0);
    }

    // -------------------------------------------------------------------------
    // Manual logging
    // -------------------------------------------------------------------------

    @Test
    void logPlayWithDetailsCreatesLogAndEntry() throws Exception {
        UUID user = user();
        UUID game = game();
        Instant playedAt = Instant.now().minus(2, ChronoUnit.DAYS).truncatedTo(ChronoUnit.SECONDS);
        Map<String, Object> body = new HashMap<>();
        body.put("playedAt", playedAt.toString());
        body.put("notes", "  Close game  ");
        body.put("durationMinutes", 75);
        body.put("playerCount", 4);

        JsonNode data = json(mvc.perform(post("/api/v1/users/me/games/{id}/plays", game).with(as(user))
                        .contentType(MediaType.APPLICATION_JSON).content(toJson(body)))
                .andExpect(status().isCreated())
                .andReturn()).get("data");

        assertThat(data.get("gameId").asText()).isEqualTo(game.toString());
        assertThat(Instant.parse(data.get("playedAt").asText())).isEqualTo(playedAt);
        assertThat(data.get("notes").asText()).isEqualTo("Close game");
        assertThat(data.get("durationMinutes").asInt()).isEqualTo(75);
        assertThat(data.get("playerCount").asInt()).isEqualTo(4);
        assertThat(data.get("postId").isNull()).isTrue();
        assertThat(playCount(user, game)).isEqualTo(1);
        // Entry created with no flags: plays alone keep it
        assertThat(count("SELECT COUNT(*) FROM user_games WHERE user_id = ? AND NOT is_owned AND NOT is_wishlisted"
                + " AND NOT is_favorited", user)).isEqualTo(1);

        mvc.perform(get("/api/v1/users/me/games/{id}/plays", game).with(as(user)))
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.data[0].durationMinutes").value(75));
    }

    @Test
    void logPlayWithoutBodyAndLegacyAliasBothCount() throws Exception {
        UUID user = user();
        UUID game = game();
        mvc.perform(post("/api/v1/users/me/games/{id}/plays", game).with(as(user)))
                .andExpect(status().isCreated());
        mvc.perform(post("/api/v1/users/me/games/{id}/log-play", game).with(as(user)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.playCount").value(2))
                .andExpect(jsonPath("$.data.game.id").value(game.toString()));
        assertThat(count("SELECT COUNT(*) FROM play_logs WHERE user_id = ?", user)).isEqualTo(2);
    }

    @Test
    void futurePlayAndOutOfRangeFieldsAreRejected() throws Exception {
        UUID user = user();
        UUID game = game();
        mvc.perform(post("/api/v1/users/me/games/{id}/plays", game).with(as(user))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(Map.of("playedAt", Instant.now().plus(1, ChronoUnit.DAYS).toString()))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_PLAYED_AT"));
        mvc.perform(post("/api/v1/users/me/games/{id}/plays", game).with(as(user))
                        .contentType(MediaType.APPLICATION_JSON).content(toJson(Map.of("durationMinutes", 0))))
                .andExpect(status().isBadRequest());
        mvc.perform(post("/api/v1/users/me/games/{id}/plays", UUID.randomUUID()).with(as(user)))
                .andExpect(status().isNotFound());
        assertThat(count("SELECT COUNT(*) FROM play_logs WHERE user_id = ?", user)).isZero();
    }

    @Test
    void deletingPlaysDecrementsAndRemovesAnEmptyEntry() throws Exception {
        UUID user = user();
        UUID game = game();
        String first = json(mvc.perform(post("/api/v1/users/me/games/{id}/plays", game).with(as(user)))
                .andReturn()).get("data").get("id").asText();
        String second = json(mvc.perform(post("/api/v1/users/me/games/{id}/plays", game).with(as(user)))
                .andReturn()).get("data").get("id").asText();

        mvc.perform(delete("/api/v1/users/me/plays/{id}", first).with(as(user)))
                .andExpect(status().isNoContent());
        assertThat(playCount(user, game)).isEqualTo(1);

        mvc.perform(delete("/api/v1/users/me/plays/{id}", second).with(as(user)))
                .andExpect(status().isNoContent());
        assertThat(playCount(user, game)).isEqualTo(-1); // entry had nothing else: deleted
    }

    @Test
    void deletingAPlayKeepsAnOwnedEntry() throws Exception {
        UUID user = user();
        UUID game = game();
        mvc.perform(put("/api/v1/users/me/games/{id}", game).with(as(user))
                .contentType(MediaType.APPLICATION_JSON).content(toJson(Map.of("isOwned", true))));
        String play = json(mvc.perform(post("/api/v1/users/me/games/{id}/plays", game).with(as(user)))
                .andReturn()).get("data").get("id").asText();

        mvc.perform(delete("/api/v1/users/me/plays/{id}", play).with(as(user)))
                .andExpect(status().isNoContent());
        assertThat(playCount(user, game)).isZero();
    }

    @Test
    void cannotDeleteSomeoneElsesPlay() throws Exception {
        UUID owner = user();
        UUID other = user();
        UUID game = game();
        String play = json(mvc.perform(post("/api/v1/users/me/games/{id}/plays", game).with(as(owner)))
                .andReturn()).get("data").get("id").asText();

        mvc.perform(delete("/api/v1/users/me/plays/{id}", play).with(as(other)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("PLAY_NOT_FOUND"));
        assertThat(playCount(owner, game)).isEqualTo(1);
    }

    // -------------------------------------------------------------------------
    // SessionPlayedEvent (published by the posts package)
    // -------------------------------------------------------------------------

    @Test
    void sessionPlayedRecordsOnePlayPerUserAndIsIdempotent() throws Exception {
        UUID author = user();
        UUID tagged = user();
        UUID deleted = user();
        softDeleteUser(deleted);
        UUID game = game();
        UUID postId = createPost(author, game);
        Instant playedAt = Instant.parse("2026-09-01T18:00:00Z");
        // The tagged user already owns the game: flags must stay as they are
        mvc.perform(put("/api/v1/users/me/games/{id}", game).with(as(tagged))
                .contentType(MediaType.APPLICATION_JSON).content(toJson(Map.of("isOwned", true))));

        SessionPlayedEvent event = new SessionPlayedEvent(List.of(author, tagged, tagged, deleted), game, playedAt, postId);
        publishInTransaction(event);
        publishInTransaction(event); // re-delivery changes nothing

        assertThat(playCount(author, game)).isEqualTo(1);
        assertThat(playCount(tagged, game)).isEqualTo(1);
        assertThat(playCount(deleted, game)).isEqualTo(-1);
        assertThat(count("SELECT COUNT(*) FROM play_logs WHERE post_id = ?", postId)).isEqualTo(2);
        assertThat(count("SELECT COUNT(*) FROM user_games WHERE user_id = ? AND is_owned", tagged)).isEqualTo(1);
        assertThat(count("SELECT COUNT(*) FROM user_games WHERE user_id = ? AND is_owned", author)).isZero();
        assertThat(jdbc.queryForObject("SELECT played_at FROM play_logs WHERE user_id = ? AND post_id = ?",
                java.sql.Timestamp.class, author, postId).toInstant()).isEqualTo(playedAt);

        mvc.perform(get("/api/v1/users/me/games/{id}/plays", game).with(as(author)))
                .andExpect(jsonPath("$.data[0].postId").value(postId.toString()));
    }

    @Test
    void sessionPlayedForAnUnknownGameOrNoUsersIsIgnored() {
        UUID author = user();
        publishInTransaction(new SessionPlayedEvent(List.of(author), UUID.randomUUID(), Instant.now(), null));
        publishInTransaction(new SessionPlayedEvent(List.of(), game(), Instant.now(), null));
        assertThat(count("SELECT COUNT(*) FROM play_logs WHERE user_id = ?", author)).isZero();
    }

    @Test
    void sessionPlayedWithoutPostStillRecordsAndWorksOutsideATransaction() {
        UUID author = user();
        UUID game = game();
        publisher.publishEvent(new SessionPlayedEvent(List.of(author), game, null, null)); // fallback execution
        assertThat(playCount(author, game)).isEqualTo(1);
        assertThat(count("SELECT COUNT(*) FROM play_logs WHERE user_id = ? AND post_id IS NULL", author)).isEqualTo(1);
    }

    // -------------------------------------------------------------------------
    // Account deletion
    // -------------------------------------------------------------------------

    @Test
    void softDeletedUserLosesCollectionPlaysAndImportHistory() throws Exception {
        UUID user = user();
        UUID keep = user();
        UUID game = game();
        mvc.perform(put("/api/v1/users/me/games/{id}", game).with(as(user))
                .contentType(MediaType.APPLICATION_JSON).content(toJson(Map.of("isOwned", true))));
        mvc.perform(post("/api/v1/users/me/games/{id}/plays", game).with(as(user)));
        mvc.perform(post("/api/v1/users/me/games/{id}/plays", game).with(as(keep)));
        jdbc.update("INSERT INTO bgg_imports (user_id, bgg_username) VALUES (?, 'someone')", user);
        redis.opsForValue().set("bgg:import:" + user, "{\"status\":\"done\"}");

        publishInTransaction(new UserSoftDeletedEvent(user));

        assertThat(count("SELECT COUNT(*) FROM user_games WHERE user_id = ?", user)).isZero();
        assertThat(count("SELECT COUNT(*) FROM play_logs WHERE user_id = ?", user)).isZero();
        assertThat(count("SELECT COUNT(*) FROM bgg_imports WHERE user_id = ?", user)).isZero();
        assertThat(redis.hasKey("bgg:import:" + user)).isFalse();
        assertThat(count("SELECT COUNT(*) FROM play_logs WHERE user_id = ?", keep)).isEqualTo(1);
    }
}
