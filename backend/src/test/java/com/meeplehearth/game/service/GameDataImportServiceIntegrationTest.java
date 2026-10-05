package com.meeplehearth.game.service;

import com.meeplehearth.support.ai.AiGameIntegrationTestBase;
import com.meeplehearth.support.ai.Fixtures;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.NoSuchFileException;
import java.nio.file.Path;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** CSV catalog import into the real schema using a small captured-format fixture. */
class GameDataImportServiceIntegrationTest extends AiGameIntegrationTestBase {

    private static final String BGG_IDS = "990000001, 990000002, 990000003, 990000004, 990000005";

    @Autowired private GameDataImportService importService;

    private Path csv;

    @BeforeEach
    void writeFixture() throws Exception {
        jdbc.update("DELETE FROM games WHERE bgg_id IN (" + BGG_IDS + ")");
        csv = Files.createTempFile("boardgames-small-", ".csv");
        Files.writeString(csv, Fixtures.read("game/boardgames-small.csv"), StandardCharsets.UTF_8);
    }

    @AfterEach
    void cleanUp() throws Exception {
        jdbc.update("DELETE FROM games WHERE bgg_id IN (" + BGG_IDS + ")");
        Files.deleteIfExists(csv);
    }

    private Map<String, Object> gameRow(long bggId) {
        return jdbc.queryForMap("SELECT id, name_en, rank, year_published, bgg_rating, users_rated, thumbnail_url, "
                + "game_type, min_players FROM games WHERE bgg_id = ?", bggId);
    }

    @Test
    void importsNewGamesAndOnlyRefreshesRankingFieldsOfExistingOnes() throws Exception {
        UUID existing = UUID.randomUUID();
        jdbc.update("INSERT INTO games (id, bgg_id, name_en, rank, bgg_rating, min_players, thumbnail_url) "
                + "VALUES (?, 990000004, 'Existing Original', 999, 5.0, 3, 'https://old/thumb.jpg')", existing);

        importService.runImport(csv.toString());

        Map<String, Object> alpha = gameRow(990000001L);
        assertThat(alpha).containsEntry("name_en", "Alpha Import").containsEntry("rank", 1)
                .containsEntry("year_published", 2001).containsEntry("users_rated", 1200)
                .containsEntry("thumbnail_url", "https://cf.geekdo-images.com/alpha.jpg")
                .containsEntry("game_type", "boardgame");
        assertThat((BigDecimal) alpha.get("bgg_rating")).isEqualByComparingTo("7.512");
        assertThat(alpha.get("min_players")).as("players come from hydration, not the CSV").isNull();
        Map<String, Object> alphaDetail = jdbc.queryForMap(
                "SELECT description, bgg_url FROM game_details WHERE game_id = ?", alpha.get("id"));
        assertThat(alphaDetail).containsEntry("description", "Alpha is great,\neven across lines")
                .containsEntry("bgg_url", "https://boardgamegeek.com/boardgame/990000001/alpha-import");

        Map<String, Object> beta = gameRow(990000002L);
        assertThat(beta).containsEntry("year_published", 2002).containsEntry("users_rated", 300)
                .containsEntry("thumbnail_url", null);
        assertThat(jdbc.queryForMap("SELECT description, bgg_url FROM game_details WHERE game_id = ?", beta.get("id")))
                .containsEntry("description", null)
                .containsEntry("bgg_url", "https://boardgamegeek.com/boardgame/990000002");

        Map<String, Object> gamma = gameRow(990000005L);
        assertThat(gamma).containsEntry("rank", null).containsEntry("year_published", null)
                .containsEntry("bgg_rating", null).containsEntry("users_rated", null)
                .containsEntry("thumbnail_url", "https://example.test/gamma.jpg");
        assertThat(jdbc.queryForMap("SELECT description, bgg_url FROM game_details WHERE game_id = ?", gamma.get("id")))
                .containsEntry("description", null).containsEntry("bgg_url", null);

        // Duplicate, unparseable id and blank title rows are skipped
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM games WHERE bgg_id IN (" + BGG_IDS + ")", Integer.class))
                .isEqualTo(4);

        Map<String, Object> updated = gameRow(990000004L);
        assertThat(updated).containsEntry("id", existing).containsEntry("name_en", "Existing Original")
                .containsEntry("rank", 6).containsEntry("year_published", 2010).containsEntry("users_rated", 5000)
                .containsEntry("min_players", 3).containsEntry("thumbnail_url", "https://old/thumb.jpg");
        assertThat((BigDecimal) updated.get("bgg_rating")).isEqualByComparingTo("8.0");
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM game_details WHERE game_id = ?", Integer.class, existing))
                .isZero();
    }

    @Test
    void reimportIsIdempotent() throws Exception {
        importService.runImport(csv.toString());
        UUID alphaId = (UUID) gameRow(990000001L).get("id");

        importService.runImport(csv.toString());

        assertThat(gameRow(990000001L).get("id")).isEqualTo(alphaId);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM games WHERE bgg_id IN (" + BGG_IDS + ")", Integer.class))
                .isEqualTo(4);
    }

    @Test
    void missingFileFails() {
        assertThatThrownBy(() -> importService.runImport(csv.resolveSibling("does-not-exist.csv").toString()))
                .isInstanceOf(NoSuchFileException.class);
    }
}
