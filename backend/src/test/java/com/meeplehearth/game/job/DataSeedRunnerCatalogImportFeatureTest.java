package com.meeplehearth.game.job;

import com.meeplehearth.config.AppProperties;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.game.service.GameDataImportService;
import com.meeplehearth.game.service.GameHydrationService;
import com.meeplehearth.support.ai.AiGameIntegrationTestBase;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.after;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.timeout;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

/** {@code POST /games/import} body: CSV import from app.seed.csv-url, no hydration (GAP 1.21). */
class DataSeedRunnerCatalogImportFeatureTest extends AiGameIntegrationTestBase {

    private static final String SEED_LOCK = "lock:games-seed";

    private final GameDataImportService importService = mock(GameDataImportService.class);
    private final GameHydrationService hydrationService = mock(GameHydrationService.class);
    private final AppProperties properties = new AppProperties();
    private DataSeedRunner runner;
    private Path csv;

    @BeforeEach
    void setUp() throws Exception {
        redis.delete(SEED_LOCK);
        csv = Files.createTempFile("catalog-", ".csv");
        Files.writeString(csv, "Rank,Game_Id,Title\n");
        runner = new DataSeedRunner(properties, importService, hydrationService, mock(GameRepository.class), redis);
    }

    @AfterEach
    void tearDown() throws Exception {
        redis.delete(SEED_LOCK);
        Files.deleteIfExists(csv);
    }

    @Test
    void withoutUrlNothingStarts() {
        properties.getSeed().setCsvUrl(" ");
        assertThat(runner.triggerCatalogImport()).isFalse();
        verifyNoInteractions(importService, hydrationService);
    }

    @Test
    void importsTheConfiguredCsvWithoutHydrating() throws Exception {
        properties.getSeed().setCsvUrl(csv.toUri().toString());

        assertThat(runner.triggerCatalogImport()).isTrue();

        verify(importService, timeout(10_000)).runImport(anyString());
        verify(hydrationService, after(200).never()).hydrateAllMissingImages();
        org.awaitility.Awaitility.await().atMost(Duration.ofSeconds(10))
                .until(() -> !Boolean.TRUE.equals(redis.hasKey(SEED_LOCK)));
    }

    @Test
    void skipsWhileAnotherSeedHoldsTheLock() throws Exception {
        properties.getSeed().setCsvUrl(csv.toUri().toString());
        redis.opsForValue().set(SEED_LOCK, "1", Duration.ofMinutes(1));

        assertThat(runner.triggerCatalogImport()).isTrue();

        verify(importService, after(500).never()).runImport(anyString());
        assertThat(redis.hasKey(SEED_LOCK)).isTrue();
    }
}
