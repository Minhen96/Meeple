package com.meeplehearth.game;

import com.fasterxml.jackson.databind.JsonNode;
import com.meeplehearth.game.client.BggApiClient;
import com.meeplehearth.game.client.FakeBggServer;
import com.meeplehearth.support.social.ApiIntegrationTestBase;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.MediaType;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.time.Duration;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;

import static org.assertj.core.api.Assertions.assertThat;
import static org.awaitility.Awaitility.await;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** BGG collection import end to end against a fake xmlapi2 server (202 queueing, 404, success). */
class BggImportFeatureTest extends ApiIntegrationTestBase {

    private static final FakeBggServer BGG;

    static {
        try {
            BGG = new FakeBggServer();
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    @DynamicPropertySource
    static void bggProperties(DynamicPropertyRegistry registry) {
        registry.add("app.bgg.xmlapi-base-url", BGG::baseUrl);
        registry.add("app.bgg.api-token", () -> "test-token");
        registry.add("app.bgg.collection-retry-delay-ms", () -> "5");
    }

    @AfterAll
    static void stopServer() {
        BGG.close();
    }

    @Autowired private StringRedisTemplate redis;
    /** New games are hydrated in the background; keep that off the network. */
    @MockitoBean private BggApiClient bggApiClient;

    private long idA;
    private long idB;
    private long idC;

    @BeforeEach
    void ids() {
        long base = 3_000_000_000L + ThreadLocalRandom.current().nextLong(1_000_000_000L);
        idA = base;
        idB = base + 1;
        idC = base + 2;
        BGG.reset();
    }

    @AfterEach
    void removeImportedGames() {
        jdbc.update("DELETE FROM games WHERE bgg_id IN (?, ?, ?)", idA, idB, idC);
    }

    private void startImport(UUID user, String username) throws Exception {
        mvc.perform(post("/api/v1/users/me/bgg-import").with(as(user))
                        .contentType(MediaType.APPLICATION_JSON).content(toJson(Map.of("bggUsername", username))))
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.data.status").value("running"));
    }

    private JsonNode awaitFinished(UUID user) {
        JsonNode[] last = new JsonNode[1];
        await().atMost(Duration.ofSeconds(20)).until(() -> {
            last[0] = json(mvc.perform(get("/api/v1/users/me/bgg-import/status").with(as(user)))
                    .andExpect(status().isOk()).andReturn()).get("data");
            String s = last[0].get("status").asText();
            return "done".equals(s) || "failed".equals(s);
        });
        return last[0];
    }

    @Test
    void importsOwnedGamesAfterQueueingAndKeepsExistingFlags() throws Exception {
        UUID user = user();
        // Game B already exists in the catalog and is on the user's wishlist; game C is already owned
        UUID existingB = UUID.randomUUID();
        jdbc.update("INSERT INTO games (id, bgg_id, name_en, min_players) VALUES (?, ?, 'Existing B', 2)", existingB, idB);
        UUID existingC = UUID.randomUUID();
        jdbc.update("INSERT INTO games (id, bgg_id, name_en, min_players) VALUES (?, ?, 'Existing C', 2)", existingC, idC);
        mvc.perform(put("/api/v1/users/me/games/{id}", existingB).with(as(user))
                .contentType(MediaType.APPLICATION_JSON).content(toJson(Map.of("isWishlisted", true))));
        mvc.perform(put("/api/v1/users/me/games/{id}", existingC).with(as(user))
                .contentType(MediaType.APPLICATION_JSON).content(toJson(Map.of("isOwned", true))));

        BGG.enqueue(202, FakeBggServer.QUEUED)
                .enqueue(200, FakeBggServer.collection(idA, "New A", idB, "Existing B", idC, "Existing C", idA, "New A"));

        startImport(user, " Alice_BGG ");
        JsonNode status = awaitFinished(user);

        assertThat(status.get("status").asText()).isEqualTo("done");
        assertThat(status.get("total").asInt()).isEqualTo(4);
        assertThat(status.get("processed").asInt()).isEqualTo(4);
        assertThat(status.get("imported").asInt()).isEqualTo(2);
        assertThat(status.get("skipped").asInt()).isEqualTo(2); // C already owned, duplicate A
        assertThat(status.get("failed").asInt()).isZero();
        assertThat(status.get("errorCode").isNull()).isTrue();
        assertThat(status.get("preview")).hasSize(2);

        assertThat(BGG.requests()).hasSize(2);
        assertThat(BGG.requests().get(0).authorization()).isEqualTo("Bearer test-token");
        assertThat(BGG.requests().get(0).query()).contains("username=Alice_BGG");

        assertThat(string("SELECT bgg_username FROM users WHERE id = ?", user)).isEqualTo("Alice_BGG");
        assertThat(string("SELECT name_en FROM games WHERE bgg_id = ?", idA)).isEqualTo("New A");
        assertThat(string("SELECT thumbnail_url FROM games WHERE bgg_id = ?", idA))
                .isEqualTo("https://cf.geekdo-images.com/t" + idA + ".jpg");
        assertThat(count("SELECT COUNT(*) FROM user_games ug JOIN games g ON g.id = ug.game_id"
                + " WHERE ug.user_id = ? AND ug.is_owned", user)).isEqualTo(3);
        assertThat(count("SELECT COUNT(*) FROM user_games WHERE user_id = ? AND game_id = ? AND is_wishlisted",
                user, existingB)).isEqualTo(1);
        assertThat(string("SELECT status FROM bgg_imports WHERE user_id = ?", user)).isEqualTo("DONE");
        assertThat(count("SELECT COUNT(*) FROM notifications WHERE recipient_id = ? AND type = 'BGG_IMPORT_COMPLETED'",
                user)).isEqualTo(1);

        // The cached collection was evicted: the new games are visible at once
        mvc.perform(get("/api/v1/users/me/games?filter=owned").with(as(user)))
                .andExpect(jsonPath("$.data.length()").value(3));
        assertThat(redis.hasKey("bgg:import:" + user + ":lock")).isFalse();
    }

    @Test
    void unknownUsernameFailsWithBggUserNotFound() throws Exception {
        UUID user = user();
        BGG.enqueue(404, "");

        startImport(user, "nobody");
        JsonNode status = awaitFinished(user);

        assertThat(status.get("status").asText()).isEqualTo("failed");
        assertThat(status.get("errorCode").asText()).isEqualTo("BGG_USER_NOT_FOUND");
        assertThat(string("SELECT error_code FROM bgg_imports WHERE user_id = ?", user)).isEqualTo("BGG_USER_NOT_FOUND");
        assertThat(count("SELECT COUNT(*) FROM notifications WHERE recipient_id = ?", user)).isZero();
    }

    @Test
    void stillQueuedAfterTenRetriesFailsWithBggApiUnavailable() throws Exception {
        UUID user = user();
        for (int i = 0; i < 11; i++) BGG.enqueue(202, FakeBggServer.QUEUED);

        startImport(user, "slowpoke");
        JsonNode status = awaitFinished(user);

        assertThat(status.get("errorCode").asText()).isEqualTo("BGG_API_UNAVAILABLE");
        assertThat(BGG.requests()).hasSize(11);
    }

    @Test
    void secondImportWhileRunningIsRejectedAndStaleRunningReportsFailed() throws Exception {
        UUID user = user();
        redis.opsForValue().set("bgg:import:" + user + ":lock", "1", Duration.ofMinutes(1));
        mvc.perform(post("/api/v1/users/me/bgg-import").with(as(user))
                        .contentType(MediaType.APPLICATION_JSON).content(toJson(Map.of("bggUsername", "x"))))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("BGG_IMPORT_IN_PROGRESS"));

        // An import whose instance died: progress says running but the lock is gone
        redis.delete("bgg:import:" + user + ":lock");
        redis.opsForValue().set("bgg:import:" + user,
                "{\"status\":\"running\",\"total\":3,\"processed\":1,\"imported\":1,\"skipped\":0,\"failed\":0}");
        mvc.perform(get("/api/v1/users/me/bgg-import/status").with(as(user)))
                .andExpect(jsonPath("$.data.status").value("failed"))
                .andExpect(jsonPath("$.data.errorCode").value("BGG_API_UNAVAILABLE"))
                .andExpect(jsonPath("$.data.imported").value(1));
        redis.delete("bgg:import:" + user);
    }

    @Test
    void statusIsIdleBeforeAnyImportAndUsernameIsValidated() throws Exception {
        UUID user = user();
        mvc.perform(get("/api/v1/users/me/bgg-import/status").with(as(user)))
                .andExpect(jsonPath("$.data.status").value("idle"))
                .andExpect(jsonPath("$.data.total").value(0));
        mvc.perform(post("/api/v1/users/me/bgg-import").with(as(user))
                        .contentType(MediaType.APPLICATION_JSON).content(toJson(Map.of("bggUsername", "<script>"))))
                .andExpect(status().isBadRequest());
        mvc.perform(post("/api/v1/users/me/bgg-import").with(as(user))
                        .contentType(MediaType.APPLICATION_JSON).content(toJson(Map.of("bggUsername", " "))))
                .andExpect(status().isBadRequest());
        assertThat(BGG.requests()).isEmpty();
    }
}
