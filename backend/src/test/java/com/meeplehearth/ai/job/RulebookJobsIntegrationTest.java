package com.meeplehearth.ai.job;

import com.meeplehearth.common.job.JobLock;
import com.meeplehearth.ai.repository.GameRulebookRepository;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.support.ai.AiGameIntegrationTestBase;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.awaitility.Awaitility.await;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Rulebook auto-fetch job and stale-ingestion sweeper against real Postgres + Redis. */
class RulebookJobsIntegrationTest extends AiGameIntegrationTestBase {

    private static final String BATCH_LOCK = "lock:rulebook-fetch-batch";
    private static final String DONE_FLAG = "test:rulebook-batch-done";

    @Autowired private RulebookAutoFetchJob job;
    @Autowired private GameRepository gameRepository;
    @Autowired private GameRulebookRepository rulebookRepository;

    @AfterEach
    void clearJobKeys() {
        redis.delete(java.util.List.of(BATCH_LOCK, DONE_FLAG, RulebookAutoFetchJob.STOP_FLAG_KEY,
                ("lock:" + StaleRulebookIngestionSweeper.LOCK_NAME)));
    }

    private Game load(UUID id) {
        return gameRepository.findById(id).orElseThrow();
    }

    private String url(String slug) {
        return "https://cdn.1j1ju.com/medias/" + slug + ".pdf";
    }

    private void awaitNoIngesting(UUID gameId) {
        await().atMost(Duration.ofSeconds(30)).until(() -> jdbc.queryForObject(
                "SELECT COUNT(*) FROM game_rulebooks WHERE game_id = ? AND status = 'ingesting'",
                Integer.class, gameId) == 0);
    }

    // -------------------------------------------------------------------------
    // fetchForGame
    // -------------------------------------------------------------------------

    @Test
    void fetchQueuesFromRuleBookOrgFirstThenOnj() {
        UUID primary = game("Primary Source Game").insert();
        when(ruleBookOrgClient.findPdfUrl("Primary Source Game")).thenReturn(Optional.of(url("primary")));
        assertThat(job.fetchForGame(load(primary))).isEqualTo(RulebookAutoFetchJob.FetchResult.QUEUED);
        assertThat(jdbc.queryForMap("SELECT source, status, pdf_url FROM game_rulebooks WHERE game_id = ?", primary))
                .containsEntry("source", "rule_book_org").containsEntry("pdf_url", url("primary"));
        verify(onjRulebookClient, never()).findPdfUrl("Primary Source Game");

        // A link that fails the allowlist is ignored and the backup source is tried
        UUID backup = game("Backup Source Game").insert();
        when(ruleBookOrgClient.findPdfUrl("Backup Source Game")).thenReturn(Optional.of("http://evil.example/x.pdf"));
        when(onjRulebookClient.findPdfUrl("Backup Source Game")).thenReturn(Optional.of(url("backup")));
        assertThat(job.fetchForGame(load(backup))).isEqualTo(RulebookAutoFetchJob.FetchResult.QUEUED);
        assertThat(jdbc.queryForObject("SELECT source FROM game_rulebooks WHERE game_id = ?", String.class, backup))
                .isEqualTo("onj");

        assertThat(redis.hasKey(RulebookAutoFetchJob.GAME_LOCK_PREFIX + primary)).isFalse();
        awaitNoIngesting(primary);
        awaitNoIngesting(backup);
        assertThat(rulebookStatus(jdbc.queryForObject("SELECT id FROM game_rulebooks WHERE game_id = ?", UUID.class, primary)))
                .as("the downloader mock returns nothing, so ingestion fails").isEqualTo("failed");
    }

    @Test
    void fetchShortCircuits() {
        UUID approved = game("Approved Fetch").insert();
        insertRulebook(approved, "onj", "approved", Instant.now());
        assertThat(job.fetchForGame(load(approved))).isEqualTo(RulebookAutoFetchJob.FetchResult.ALREADY_APPROVED);

        UUID active = game("Active Fetch").insert();
        insertRulebook(active, "onj", "ingesting", Instant.now());
        assertThat(job.fetchForGame(load(active))).isEqualTo(RulebookAutoFetchJob.FetchResult.IN_PROGRESS);

        UUID locked = game("Locked Fetch").insert();
        redis.opsForValue().set(RulebookAutoFetchJob.GAME_LOCK_PREFIX + locked, "1");
        assertThat(job.fetchForGame(load(locked))).isEqualTo(RulebookAutoFetchJob.FetchResult.IN_PROGRESS);
        assertThat(redis.hasKey(RulebookAutoFetchJob.GAME_LOCK_PREFIX + locked)).as("foreign lock kept").isTrue();

        UUID missing = game("Missing Fetch").insert();
        assertThat(job.fetchForGame(load(missing))).isEqualTo(RulebookAutoFetchJob.FetchResult.NOT_FOUND);

        verify(ruleBookOrgClient, never()).findPdfUrl("Approved Fetch");
        verify(ruleBookOrgClient, never()).findPdfUrl("Active Fetch");
        verify(ruleBookOrgClient, never()).findPdfUrl("Locked Fetch");
    }

    @Test
    void staleIngestionDoesNotBlockANewFetch() {
        UUID gameId = game("Stale Fetch").insert();
        insertRulebook(gameId, "onj", "ingesting", Instant.now().minus(Duration.ofHours(2)));
        when(ruleBookOrgClient.findPdfUrl("Stale Fetch")).thenReturn(Optional.of(url("stale")));

        assertThat(job.fetchForGame(load(gameId))).isEqualTo(RulebookAutoFetchJob.FetchResult.QUEUED);
        await().atMost(Duration.ofSeconds(30)).until(() -> jdbc.queryForObject(
                "SELECT COUNT(*) FROM game_rulebooks WHERE game_id = ? AND status = 'failed'", Integer.class, gameId) == 1);
    }

    @Test
    void saveFailureIsReportedAsError() {
        Game detached = new Game();
        detached.setId(UUID.randomUUID());
        detached.setNameEn("Not Persisted Game");
        when(ruleBookOrgClient.findPdfUrl("Not Persisted Game")).thenReturn(Optional.of(url("ghost")));

        assertThat(job.fetchForGame(detached)).isEqualTo(RulebookAutoFetchJob.FetchResult.ERROR);
        assertThat(redis.hasKey(RulebookAutoFetchJob.GAME_LOCK_PREFIX + detached.getId())).isFalse();
    }

    // -------------------------------------------------------------------------
    // runBatch
    // -------------------------------------------------------------------------

    @Test
    void batchFetchesTopRankedGamesUpToLimitAndSetsCompletionFlag() {
        UUID first = game("Batch First").insert();
        UUID second = game("Batch Second").insert();
        UUID third = game("Batch Third").insert();
        when(ruleBookOrgClient.findPdfUrl("Batch First")).thenReturn(Optional.of(url("first")));
        when(onjRulebookClient.findPdfUrl("Batch Second")).thenReturn(Optional.of(url("second")));

        job.runBatch(2, DONE_FLAG);

        assertThat(redis.hasKey(DONE_FLAG)).isTrue();
        assertThat(redis.hasKey(BATCH_LOCK)).isFalse();
        verify(ruleBookOrgClient, never()).findPdfUrl("Batch Third");
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM game_rulebooks WHERE game_id IN (?, ?)",
                Integer.class, first, second)).isEqualTo(2);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM game_rulebooks WHERE game_id = ?", Integer.class, third))
                .isZero();
        awaitNoIngesting(first);
        awaitNoIngesting(second);
    }

    @Test
    void batchHonoursStopFlagAndRunLock() {
        game("Stopped Batch Game").insert();

        redis.opsForValue().set(RulebookAutoFetchJob.STOP_FLAG_KEY, "1");
        job.runBatch(1, DONE_FLAG);
        verify(ruleBookOrgClient, never()).findPdfUrl(anyString());
        assertThat(redis.hasKey(DONE_FLAG)).as("a stopped run still completes").isTrue();

        redis.delete(java.util.List.of(DONE_FLAG, RulebookAutoFetchJob.STOP_FLAG_KEY));
        redis.opsForValue().set(BATCH_LOCK, "1");
        job.runBatch(1, DONE_FLAG);
        assertThat(redis.hasKey(DONE_FLAG)).as("skipped while another batch runs").isFalse();
        assertThat(redis.hasKey(BATCH_LOCK)).as("other run's lock untouched").isTrue();

        redis.delete(BATCH_LOCK);
        job.runBatch(1, null);
        assertThat(redis.hasKey(BATCH_LOCK)).isFalse();
    }

    @Test
    void startupRunnerDoesNothing() {
        job.run(null);
        verify(ruleBookOrgClient, never()).findPdfUrl(anyString());
    }

    // -------------------------------------------------------------------------
    // Stale ingestion sweeper
    // -------------------------------------------------------------------------

    @Test
    void sweeperFailsOnlyStaleIngestionsAndReleasesItsLock() {
        UUID gameId = game("Sweep Game").insert();
        UUID stale = insertRulebook(gameId, "onj", "ingesting", Instant.now().minus(Duration.ofHours(2)));
        UUID fresh = insertRulebook(gameId, "onj", "ingesting", Instant.now().minus(Duration.ofMinutes(10)));

        // Clock in the past: nothing is stale yet
        new StaleRulebookIngestionSweeper(rulebookRepository, new JobLock(redis),
                Clock.fixed(Instant.now().minus(Duration.ofHours(3)), ZoneOffset.UTC)).sweep();
        assertThat(rulebookStatus(stale)).isEqualTo("ingesting");

        new StaleRulebookIngestionSweeper(rulebookRepository, new JobLock(redis)).sweep();
        assertThat(rulebookStatus(stale)).isEqualTo("failed");
        assertThat(rulebookStatus(fresh)).isEqualTo("ingesting");
        assertThat(redis.hasKey(("lock:" + StaleRulebookIngestionSweeper.LOCK_NAME))).isFalse();
        jdbc.update("UPDATE game_rulebooks SET status = 'failed' WHERE id = ?", fresh);
    }

    @Test
    void sweeperSkipsWhileAnotherInstanceHoldsTheLock() {
        UUID gameId = game("Sweep Locked Game").insert();
        UUID stale = insertRulebook(gameId, "onj", "ingesting", Instant.now().minus(Duration.ofHours(2)));
        redis.opsForValue().set(("lock:" + StaleRulebookIngestionSweeper.LOCK_NAME), "other-instance");

        new StaleRulebookIngestionSweeper(rulebookRepository, new JobLock(redis)).sweep();

        assertThat(rulebookStatus(stale)).isEqualTo("ingesting");
        assertThat(redis.opsForValue().get(("lock:" + StaleRulebookIngestionSweeper.LOCK_NAME))).isEqualTo("other-instance");
        jdbc.update("UPDATE game_rulebooks SET status = 'failed' WHERE id = ?", stale);
    }

    @Test
    void sweeperSurvivesRepositoryErrors() {
        GameRulebookRepository failing = mock(GameRulebookRepository.class);
        when(failing.markStaleIngestingFailed(any())).thenThrow(new IllegalStateException("db down"));

        new StaleRulebookIngestionSweeper(failing, new JobLock(redis)).sweep();

        assertThat(redis.hasKey(("lock:" + StaleRulebookIngestionSweeper.LOCK_NAME))).isFalse();
    }
}
