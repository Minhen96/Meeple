package com.meeplehearth.game.controller;

import com.meeplehearth.ai.job.RulebookAutoFetchJob;
import com.meeplehearth.config.AppProperties;
import com.meeplehearth.game.job.DataSeedRunner;
import com.meeplehearth.game.service.GameHydrationService;
import com.meeplehearth.support.ai.AiGameIntegrationTestBase;
import okhttp3.mockwebserver.MockResponse;
import okhttp3.mockwebserver.MockWebServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.ResultActions;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.awaitility.Awaitility.await;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Admin system-setup status / start / stop / reset / CSV probe endpoints. */
class AdminSetupControllerIntegrationTest extends AiGameIntegrationTestBase {

    private static final List<String> FLAGS = List.of(DataSeedRunner.GAMES_IMPORTED_FLAG,
            DataSeedRunner.HYDRATION_STARTED_FLAG, GameHydrationService.STOP_FLAG_KEY,
            GameHydrationService.RUN_LOCK_KEY, RulebookAutoFetchJob.INIT_FLAG_KEY, RulebookAutoFetchJob.STOP_FLAG_KEY);

    @Autowired private AppProperties appProperties;

    private UUID admin;
    private String originalCsvUrl;

    @BeforeEach
    void setUp() {
        admin = createUser("ADMIN");
        originalCsvUrl = appProperties.getSeed().getCsvUrl();
        redis.delete(FLAGS);
    }

    @AfterEach
    void restore() {
        appProperties.getSeed().setCsvUrl(originalCsvUrl);
        redis.delete(FLAGS);
    }

    private ResultActions call(String method, String path) throws Exception {
        var builder = "GET".equals(method) ? get("/api/v1/admin/setup" + path) : post("/api/v1/admin/setup" + path);
        return mvc.perform(builder.cookie(auth(admin)));
    }

    private long count(String sql) {
        Long n = jdbc.queryForObject(sql, Long.class);
        return n == null ? 0 : n;
    }

    @Test
    void statusReportsFlagsAndProgress() throws Exception {
        game("Setup hydrated").insert();
        game("Setup raw").unhydrated().insert();
        UUID withRulebook = game("Setup rulebook").insert();
        insertRulebook(withRulebook, "onj", "approved", Instant.now());
        UUID ingesting = game("Setup ingesting").insert();
        insertRulebook(ingesting, "onj", "ingesting", Instant.now());
        redis.opsForValue().set(DataSeedRunner.GAMES_IMPORTED_FLAG, "1");
        redis.opsForValue().set(GameHydrationService.RUN_LOCK_KEY, "1");
        redis.opsForValue().set(RulebookAutoFetchJob.STOP_FLAG_KEY, "1");

        long total = count("SELECT COUNT(*) FROM games");
        long unhydrated = count("SELECT COUNT(*) FROM games WHERE min_players IS NULL");
        long approved = count("SELECT COUNT(*) FROM game_rulebooks WHERE status = 'approved'");

        call("GET", "/status")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.catalog.imported").value(true))
                .andExpect(jsonPath("$.data.catalog.totalGames").value((int) total))
                .andExpect(jsonPath("$.data.hydration.started").value(false))
                .andExpect(jsonPath("$.data.hydration.unhydrated").value((int) unhydrated))
                .andExpect(jsonPath("$.data.hydration.hydrated").value((int) (total - unhydrated)))
                .andExpect(jsonPath("$.data.hydration.percentDone").value((int) ((total - unhydrated) * 100 / total)))
                .andExpect(jsonPath("$.data.hydration.running").value(true))
                .andExpect(jsonPath("$.data.hydration.stopRequested").value(false))
                .andExpect(jsonPath("$.data.rulebooks.approved").value((int) approved))
                .andExpect(jsonPath("$.data.rulebooks.target").value((int) Math.min(total, 10_000)))
                .andExpect(jsonPath("$.data.rulebooks.running").value(false))
                .andExpect(jsonPath("$.data.rulebooks.stopRequested").value(true))
                .andExpect(jsonPath("$.data.rulebooks.pumpStarted").value(false));

        redis.delete(RulebookAutoFetchJob.STOP_FLAG_KEY);
        call("GET", "/status").andExpect(jsonPath("$.data.rulebooks.running").value(true));
    }

    @Test
    void startStepsDelegateOrRunThePump() throws Exception {
        call("POST", "/start/import").andExpect(jsonPath("$.data.message")
                .value("Import triggered — downloading CSV and importing catalog."));
        verify(dataSeedRunner).triggerImport();
        call("POST", "/start/hydrate").andExpect(jsonPath("$.data.message").value("BGG hydration triggered."));
        verify(dataSeedRunner).triggerHydration();

        game("Pump candidate").insert();
        redis.opsForValue().set(RulebookAutoFetchJob.STOP_FLAG_KEY, "1");
        call("POST", "/start/rulebooks").andExpect(status().isOk());
        // The pump runs in the background; with no rulebook found for any game it still completes
        await().atMost(Duration.ofSeconds(60)).until(() -> redis.hasKey(RulebookAutoFetchJob.INIT_FLAG_KEY));
        assertThat(redis.hasKey(RulebookAutoFetchJob.STOP_FLAG_KEY)).isFalse();

        call("POST", "/start/everything")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.data.error").value("Unknown step. Use: import | hydrate | rulebooks"));
    }

    @Test
    void stopAndResetFlags() throws Exception {
        call("POST", "/stop/hydrate").andExpect(status().isOk());
        call("POST", "/stop/rulebooks").andExpect(status().isOk());
        assertThat(redis.hasKey(GameHydrationService.STOP_FLAG_KEY)).isTrue();
        assertThat(redis.hasKey(RulebookAutoFetchJob.STOP_FLAG_KEY)).isTrue();
        call("GET", "/status").andExpect(jsonPath("$.data.hydration.stopRequested").value(true));

        call("POST", "/stop/import").andExpect(status().isBadRequest());

        redis.opsForValue().set(DataSeedRunner.GAMES_IMPORTED_FLAG, "1");
        redis.opsForValue().set(RulebookAutoFetchJob.INIT_FLAG_KEY, "1");
        call("POST", "/reset").andExpect(jsonPath("$.data.message").exists());
        for (String key : List.of(DataSeedRunner.GAMES_IMPORTED_FLAG, DataSeedRunner.HYDRATION_STARTED_FLAG,
                RulebookAutoFetchJob.INIT_FLAG_KEY, GameHydrationService.STOP_FLAG_KEY, RulebookAutoFetchJob.STOP_FLAG_KEY)) {
            assertThat(redis.hasKey(key)).as(key).isFalse();
        }
    }

    @Test
    void csvProbeReportsSizeAndReachability() throws Exception {
        appProperties.getSeed().setCsvUrl("");
        call("GET", "/check-csv")
                .andExpect(jsonPath("$.data.accessible").value(false))
                .andExpect(jsonPath("$.data.error").value("SEED_CSV_URL is not configured"));

        try (MockWebServer server = new MockWebServer()) {
            server.start();
            String url = "http://localhost:" + server.getPort() + "/boardgames.csv";
            appProperties.getSeed().setCsvUrl(url);

            server.enqueue(new MockResponse().setHeader("Content-Type", "text/csv")
                    .setHeader("Content-Length", "2097152"));
            call("GET", "/check-csv")
                    .andExpect(jsonPath("$.data.url").value(url))
                    .andExpect(jsonPath("$.data.accessible").value(true))
                    .andExpect(jsonPath("$.data.httpStatus").value(200))
                    .andExpect(jsonPath("$.data.contentType").value("text/csv"))
                    .andExpect(jsonPath("$.data.sizeBytes").value(2097152))
                    .andExpect(jsonPath("$.data.sizeMb").value("2.0 MB"))
                    .andExpect(jsonPath("$.data.pass").value(true));
            assertThat(server.takeRequest().getMethod()).isEqualTo("HEAD");

            server.enqueue(new MockResponse().setHeader("Content-Length", "12"));
            call("GET", "/check-csv")
                    .andExpect(jsonPath("$.data.pass").value(false))
                    .andExpect(jsonPath("$.data.verdict")
                            .value("File is too small or size unknown — verify the correct file is uploaded."));

            server.enqueue(new MockResponse().setResponseCode(403));
            call("GET", "/check-csv")
                    .andExpect(jsonPath("$.data.accessible").value(false))
                    .andExpect(jsonPath("$.data.error").exists());
        }
    }

    @Test
    void setupIsAdminOnly() throws Exception {
        mvc.perform(get("/api/v1/admin/setup/status").cookie(auth(createUser())))
                .andExpect(status().isForbidden());
    }
}
