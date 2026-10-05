package com.meeplehearth.game.job;

import com.meeplehearth.config.AppProperties;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.game.service.GameDataImportService;
import com.meeplehearth.game.service.GameHydrationService;
import com.meeplehearth.support.ai.AiGameIntegrationTestBase;
import com.meeplehearth.support.ai.Fixtures;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.List;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;
import static org.awaitility.Awaitility.await;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.after;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.timeout;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/**
 * Seed orchestration (flags, distributed lock, CSV download, import, hydration hand-off) with real
 * Redis; the import / hydration services and the game count are stubbed so the steps can be steered.
 */
class DataSeedRunnerTest extends AiGameIntegrationTestBase {

    private static final String SEED_LOCK = "lock:games-seed";
    private static final List<String> KEYS = List.of(DataSeedRunner.GAMES_IMPORTED_FLAG,
            DataSeedRunner.HYDRATION_STARTED_FLAG, SEED_LOCK, GameHydrationService.STOP_FLAG_KEY);

    private final GameDataImportService importService = mock(GameDataImportService.class);
    private final GameHydrationService hydrationService = mock(GameHydrationService.class);
    private final GameRepository games = mock(GameRepository.class);
    private final AppProperties properties = new AppProperties();
    private DataSeedRunner runner;
    private Path csv;

    @BeforeEach
    void setUp() throws Exception {
        redis.delete(KEYS);
        csv = Files.createTempFile("seed-", ".csv");
        Files.writeString(csv, Fixtures.read("game/boardgames-small.csv"), StandardCharsets.UTF_8);
        properties.getSeed().setCsvUrl(csv.toUri().toString());
        runner = new DataSeedRunner(properties, importService, hydrationService, games, redis);
    }

    @AfterEach
    void tearDown() throws Exception {
        redis.delete(KEYS);
        Files.deleteIfExists(csv);
    }

    private void awaitSeedFinished() {
        await().atMost(Duration.ofSeconds(10)).until(() -> !Boolean.TRUE.equals(redis.hasKey(SEED_LOCK)));
    }

    @Test
    void startupDoesNothing() {
        runner.run(null);
        verifyNoInteractions(importService, hydrationService, games);
    }

    @Test
    void manualHydrationResetsFlagsAndStarts() {
        redis.opsForValue().set(GameHydrationService.STOP_FLAG_KEY, "1");

        runner.triggerHydration();

        verify(hydrationService).hydrateAllMissingImages();
        assertThat(redis.hasKey(DataSeedRunner.HYDRATION_STARTED_FLAG)).isTrue();
        assertThat(redis.hasKey(GameHydrationService.STOP_FLAG_KEY)).isFalse();
    }

    @Test
    void importDownloadsCsvToTempFileImportsAndStartsHydration() throws Exception {
        when(games.count()).thenReturn(0L);
        when(games.countByMinPlayersIsNull()).thenReturn(4L);
        AtomicReference<String> imported = new AtomicReference<>();
        AtomicReference<String> content = new AtomicReference<>();
        doAnswer(inv -> {
            String path = inv.getArgument(0);
            imported.set(path);
            content.set(Files.readString(Path.of(path)));
            return null;
        }).when(importService).runImport(anyString());
        redis.opsForValue().set(DataSeedRunner.GAMES_IMPORTED_FLAG, "stale");

        runner.triggerImport();

        verify(hydrationService, timeout(10_000)).hydrateAllMissingImages();
        awaitSeedFinished();
        assertThat(content.get()).isEqualTo(Fixtures.read("game/boardgames-small.csv"));
        assertThat(imported.get()).isNotEqualTo(csv.toString());
        assertThat(Path.of(imported.get())).as("temp download is deleted").doesNotExist();
        assertThat(redis.opsForValue().get(DataSeedRunner.GAMES_IMPORTED_FLAG)).isEqualTo("1");
        assertThat(redis.hasKey(DataSeedRunner.HYDRATION_STARTED_FLAG)).isTrue();
    }

    @Test
    void nonEmptyCatalogIsMarkedImportedWithoutDownloading() throws Exception {
        when(games.count()).thenReturn(10L);
        when(games.countByMinPlayersIsNull()).thenReturn(0L);

        runner.triggerImport();

        await().atMost(Duration.ofSeconds(10)).until(() -> redis.hasKey(DataSeedRunner.HYDRATION_STARTED_FLAG));
        awaitSeedFinished();
        verify(importService, never()).runImport(anyString());
        verify(hydrationService, never()).hydrateAllMissingImages();
        assertThat(redis.hasKey(DataSeedRunner.GAMES_IMPORTED_FLAG)).isTrue();
    }

    @Test
    void missingCsvUrlSkipsImportButStillHydrates() throws Exception {
        properties.getSeed().setCsvUrl(" ");
        when(games.countByMinPlayersIsNull()).thenReturn(1L);

        runner.triggerImport();

        verify(hydrationService, timeout(10_000)).hydrateAllMissingImages();
        awaitSeedFinished();
        verify(importService, never()).runImport(anyString());
        verify(games, never()).count();
        assertThat(redis.hasKey(DataSeedRunner.GAMES_IMPORTED_FLAG)).isFalse();
    }

    @Test
    void failedImportOrDownloadAbortsBeforeHydration() throws Exception {
        when(games.count()).thenReturn(0L);
        doThrow(new IllegalStateException("bad csv")).when(importService).runImport(anyString());

        runner.triggerImport();
        verify(importService, timeout(10_000)).runImport(anyString());
        awaitSeedFinished();
        assertThat(redis.hasKey(DataSeedRunner.GAMES_IMPORTED_FLAG)).isFalse();
        assertThat(redis.hasKey(DataSeedRunner.HYDRATION_STARTED_FLAG)).isFalse();

        properties.getSeed().setCsvUrl(csv.resolveSibling("missing-" + System.nanoTime() + ".csv").toUri().toString());
        runner.triggerImport();
        verify(games, timeout(10_000).times(2)).count();
        awaitSeedFinished();
        verify(importService, after(300).times(1)).runImport(anyString());
        verify(hydrationService, never()).hydrateAllMissingImages();
    }

    @Test
    void concurrentSeedIsSkippedWhileLockIsHeld() throws Exception {
        redis.opsForValue().set(SEED_LOCK, "1");

        runner.triggerImport();

        verify(games, after(500).never()).count();
        verify(hydrationService, never()).hydrateAllMissingImages();
        assertThat(redis.hasKey(SEED_LOCK)).as("other seeder's lock kept").isTrue();
    }
}
