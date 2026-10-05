package com.meeplehearth.game.service;

import com.meeplehearth.game.client.BggApiClient;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.repository.GameDetailRepository;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.support.ai.AiGameIntegrationTestBase;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.PageRequest;
import org.springframework.transaction.PlatformTransactionManager;

import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Hydration persistence against the real schema: a service instance wired to the real repositories,
 * Redis and transaction manager, with only the BGG client mocked and no delays.
 */
class GameHydrationServiceIntegrationTest extends AiGameIntegrationTestBase {

    @Autowired private GameRepository gameRepository;
    @Autowired private GameDetailRepository gameDetailRepository;
    @Autowired private PlatformTransactionManager transactionManager;

    private final BggApiClient bgg = mock(BggApiClient.class);
    private GameHydrationService service;

    @BeforeEach
    void createService() {
        service = new GameHydrationService(gameRepository, gameDetailRepository, bgg, redis, transactionManager, 0, 0, 168);
        redis.delete(List.of(GameHydrationService.STOP_FLAG_KEY, GameHydrationService.RUN_LOCK_KEY));
    }

    @AfterEach
    void clearFlags() {
        redis.delete(List.of(GameHydrationService.STOP_FLAG_KEY, GameHydrationService.RUN_LOCK_KEY));
    }

    private static BggApiClient.BggGameDetail detail(long bggId, Integer minPlayers, String description, String subtype,
                                                     String[] mechanics) {
        return new BggApiClient.BggGameDetail(bggId, "t", "//cf.geekdo-images.com/thumb.png", "//cf.geekdo-images.com/img.png",
                description, 1999, minPlayers, minPlayers == null ? null : 5, 30, 60, null, null,
                mechanics, new String[]{"Fantasy"}, new String[]{"Thematic Games"}, new String[]{"D"},
                new String[]{"A"}, new String[]{"P"}, new String[]{"H"}, new String[]{"1", "2"}, subtype,
                "https://boardgamegeek.com/boardgame/" + bggId);
    }

    private static BggApiClient.BggBatchResult found(BggApiClient.BggGameDetail... details) {
        Set<Long> ids = new HashSet<>();
        for (BggApiClient.BggGameDetail d : details) ids.add(d.bggId());
        return new BggApiClient.BggBatchResult(List.of(details), ids, Set.of(), Set.of());
    }

    @Test
    void batchFillsGameAndCreatesOrUpdatesDetails() {
        GameSeed withoutDetail = game("Hydrate New Detail").unhydrated();
        UUID newId = withoutDetail.insert();
        GameSeed withDetail = game("Hydrate Existing Detail").unhydrated().description("Keep me").mechanics("Old");
        UUID existingId = withDetail.insert();

        when(bgg.fetchDetails(anyList())).thenReturn(found(
                detail(withoutDetail.bggId(), 2, "<fresh>", "boardgameexpansion", new String[]{"Drafting"}),
                detail(withDetail.bggId(), null, "  ", null, new String[0])));

        assertThat(service.hydrateBatch(List.of(withoutDetail.bggId(), withDetail.bggId()))).isEqualTo(2);

        Map<String, Object> fresh = jdbc.queryForMap("SELECT min_players, max_players, play_time, game_type, thumbnail_url, "
                + "image_url, hydration_attempted_at FROM games WHERE id = ?", newId);
        assertThat(fresh).containsEntry("min_players", 2).containsEntry("max_players", 5).containsEntry("play_time", 30)
                .containsEntry("game_type", "boardgameexpansion")
                .containsEntry("thumbnail_url", "https://cf.geekdo-images.com/thumb.png")
                .containsEntry("image_url", "https://cf.geekdo-images.com/img.png");
        assertThat(fresh.get("hydration_attempted_at")).isNotNull();
        Map<String, Object> freshDetail = jdbc.queryForMap(
                "SELECT description, array_to_string(mechanics, ',') AS mech, array_to_string(families, ',') AS fam, "
                        + "array_to_string(expansions, ',') AS exp, bgg_url FROM game_details WHERE game_id = ?", newId);
        assertThat(freshDetail).containsEntry("description", "<fresh>").containsEntry("mech", "Drafting")
                .containsEntry("fam", "Thematic Games").containsEntry("exp", "1,2");

        // No player count from BGG: sentinel 0 marks it hydrated; blank description / empty arrays keep old values
        Map<String, Object> existing = jdbc.queryForMap(
                "SELECT g.min_players, g.game_type, d.description, array_to_string(d.mechanics, ',') AS mech "
                        + "FROM games g JOIN game_details d ON d.game_id = g.id WHERE g.id = ?", existingId);
        assertThat(existing).containsEntry("min_players", 0).containsEntry("game_type", "boardgame")
                .containsEntry("description", "Keep me").containsEntry("mech", "Old");
    }

    @Test
    void sparseBggAnswerOnlyMarksTheGameHydrated() {
        GameSeed seed = game("Sparse answer").unhydrated().thumbnail("https://keep/thumb.png").description("Keep");
        UUID id = seed.insert();
        when(bgg.fetchDetails(anyList())).thenReturn(found(new BggApiClient.BggGameDetail(seed.bggId(), null, null, null,
                null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null)));

        assertThat(service.hydrateBatch(List.of(seed.bggId()))).isEqualTo(1);

        Map<String, Object> row = jdbc.queryForMap("SELECT g.min_players, g.thumbnail_url, g.play_time, g.game_type, "
                + "d.description, d.bgg_url FROM games g JOIN game_details d ON d.game_id = g.id WHERE g.id = ?", id);
        assertThat(row).containsEntry("min_players", 0).containsEntry("thumbnail_url", "https://keep/thumb.png")
                .containsEntry("play_time", 60).containsEntry("game_type", "boardgame")
                .containsEntry("description", "Keep").containsEntry("bgg_url", null);
    }

    @Test
    void duplicateDetailsForOneIdUseTheFirst() {
        GameSeed seed = game("Duplicate answer").unhydrated();
        UUID id = seed.insert();
        when(bgg.fetchDetails(anyList())).thenReturn(new BggApiClient.BggBatchResult(List.of(
                detail(seed.bggId(), 2, "first", null, new String[0]),
                detail(seed.bggId(), 4, "second", null, new String[0])), Set.of(seed.bggId()), Set.of(), Set.of()));

        assertThat(service.hydrateBatch(List.of(seed.bggId()))).isEqualTo(1);
        assertThat(jdbc.queryForObject("SELECT min_players FROM games WHERE id = ?", Integer.class, id)).isEqualTo(2);
    }

    @Test
    void batchEdgeCases() {
        assertThat(service.hydrateBatch(List.of())).isZero();
        assertThat(service.hydrateBatch(null)).isZero();
        verify(bgg, never()).fetchDetails(anyList());

        when(bgg.fetchDetails(anyList())).thenReturn(null);
        assertThatThrownBy(() -> service.hydrateBatch(List.of(1L)))
                .isInstanceOf(BggApiClient.BggUnavailableException.class);

        when(bgg.fetchDetails(anyList())).thenReturn(new BggApiClient.BggBatchResult(List.of(), Set.of(), Set.of(1L), Set.of()));
        assertThat(service.hydrateBatch(List.of(1L))).isZero();

        // Details for an id we do not have are ignored
        when(bgg.fetchDetails(anyList())).thenReturn(found(detail(-424242L, 2, "x", null, new String[0])));
        assertThat(service.hydrateBatch(List.of(-424242L))).isZero();
    }

    @Test
    void syncAndQuietVariantsNeverThrow() {
        Game hydrated = new Game();
        hydrated.setMinPlayers(2);
        hydrated.setBggId(1L);
        assertThat(service.hydrateImageSync(hydrated)).isFalse();
        Game noBggId = new Game();
        assertThat(service.hydrateImageSync(noBggId)).isFalse();
        verify(bgg, never()).fetchDetails(anyList());

        Game raw = new Game();
        raw.setBggId(5L);
        when(bgg.fetchDetails(anyList())).thenThrow(new IllegalStateException("boom"));
        assertThat(service.hydrateImageSync(raw)).isFalse();
        service.hydrateImagesQuietly(List.of(5L));

        org.mockito.Mockito.doThrow(new BggApiClient.BggUnavailableException("open")).when(bgg).fetchDetails(anyList());
        service.hydrateImagesQuietly(List.of(5L));
        assertThat(service.hydrateImageSync(raw)).isFalse();
    }

    @Test
    void candidatesExcludeRecentlyAttemptedGames() {
        UUID recent = game("Recently attempted").unhydrated().hydrationAttemptedAt(Instant.now().minus(Duration.ofHours(1))).insert();
        UUID old = game("Attempted long ago").unhydrated().hydrationAttemptedAt(Instant.now().minus(Duration.ofDays(30))).insert();
        UUID never = game("Never attempted").unhydrated().insert();
        UUID done = game("Hydrated").insert();

        List<UUID> ids = gameRepository.findHydrationCandidates(Instant.now().minus(Duration.ofDays(7)), PageRequest.of(0, 500))
                .stream().map(Game::getId).toList();

        assertThat(ids).contains(old, never).doesNotContain(recent, done);
        assertThat(ids.indexOf(old)).as("ordered by rank").isLessThan(ids.indexOf(never));
    }

    @Test
    void bulkRunHydratesMarksResolvedGamesAndStopsOnRequest() {
        GameSeed hit = game("Bulk hit").unhydrated();
        UUID hitId = hit.insert();
        GameSeed missing = game("Bulk missing on BGG").unhydrated();
        UUID missingId = missing.insert();
        GameSeed flaky = game("Bulk flaky").unhydrated();
        UUID flakyId = flaky.insert();

        when(bgg.fetchDetails(anyList())).thenAnswer(inv -> {
            List<Long> ids = inv.getArgument(0);
            Set<Long> failed = new HashSet<>(ids);
            failed.remove(hit.bggId());
            failed.remove(missing.bggId());
            // stop after this batch
            redis.opsForValue().set(GameHydrationService.STOP_FLAG_KEY, "1");
            return new BggApiClient.BggBatchResult(List.of(detail(hit.bggId(), 3, "d", null, new String[0])),
                    Set.of(hit.bggId()), Set.of(missing.bggId()), failed);
        });

        assertThat(service.runBulkHydration()).isEqualTo(1);

        assertThat(jdbc.queryForObject("SELECT min_players FROM games WHERE id = ?", Integer.class, hitId)).isEqualTo(3);
        assertThat(jdbc.queryForObject("SELECT hydration_attempted_at FROM games WHERE id = ?", Timestamp.class, missingId))
                .as("404 on BGG is a definitive answer").isNotNull();
        assertThat(jdbc.queryForObject("SELECT hydration_attempted_at FROM games WHERE id = ?", Timestamp.class, flakyId))
                .as("transient failures stay candidates").isNull();
        assertThat(service.isBulkRunning()).isFalse();
    }

    @Test
    void bulkRunSkipsWhenLockedOrStopped() {
        game("Bulk locked candidate").unhydrated().insert();

        redis.opsForValue().set(GameHydrationService.RUN_LOCK_KEY, "1");
        assertThat(service.isBulkRunning()).isTrue();
        assertThat(service.runBulkHydration()).isZero();
        assertThat(redis.hasKey(GameHydrationService.RUN_LOCK_KEY)).as("other run's lock kept").isTrue();
        redis.delete(GameHydrationService.RUN_LOCK_KEY);

        redis.opsForValue().set(GameHydrationService.STOP_FLAG_KEY, "1");
        assertThat(service.runBulkHydration()).isZero();
        verify(bgg, never()).fetchDetails(anyList());
        assertThat(service.isBulkRunning()).isFalse();
    }

    @Test
    void bulkRunGivesUpAfterConsecutiveBggOutages() {
        game("Bulk outage candidate").unhydrated().insert();
        when(bgg.fetchDetails(anyList())).thenThrow(new BggApiClient.BggUnavailableException("down"));

        assertThat(service.runBulkHydration()).isZero();
        verify(bgg, org.mockito.Mockito.times(GameHydrationService.MAX_CONSECUTIVE_FAILURES)).fetchDetails(anyList());
    }

    @Test
    void asyncEntryPointRunsTheBulkLoop() {
        game("Bulk async candidate").unhydrated().insert();
        when(bgg.fetchDetails(anyList())).thenThrow(new BggApiClient.BggUnavailableException("down"));

        service.hydrateAllMissingImages(); // plain instance: runs synchronously

        assertThat(service.isBulkRunning()).isFalse();
        verify(bgg, org.mockito.Mockito.times(GameHydrationService.MAX_CONSECUTIVE_FAILURES)).fetchDetails(anyList());
    }
}
