package com.meeplehearth.support.ai;

import com.meeplehearth.ai.client.BggRulebookClient;
import com.meeplehearth.ai.client.OnjRulebookClient;
import com.meeplehearth.ai.client.RuleBookOrgClient;
import com.meeplehearth.ai.client.SafePdfDownloader;
import com.meeplehearth.auth.util.JwtUtil;
import com.meeplehearth.game.client.BggApiClient;
import com.meeplehearth.game.job.DataSeedRunner;
import jakarta.servlet.http.Cookie;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import software.amazon.awssdk.core.ResponseInputStream;
import software.amazon.awssdk.http.AbortableInputStream;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectResponse;

import java.io.ByteArrayInputStream;
import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.atomic.AtomicInteger;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

/**
 * Shared Spring context for the ai / game integration tests: real Postgres (pgvector) and Redis,
 * real controllers/services/repositories, the AI provider replaced by {@link FakeOpenAi}
 * (MockWebServer) and only the outbound third-party client beans (R2, BGG, rulebook sites,
 * PDF downloader) replaced by Mockito mocks. Admin endpoints are NOT opened, so role checks apply.
 *
 * Every row created through the helpers is deleted after each test, together with any Redis
 * key that mentions one of the created ids.
 */
@SpringBootTest
@AutoConfigureMockMvc
public abstract class AiGameIntegrationTestBase {

    protected static final FakeOpenAi OPENAI = FakeOpenAi.instance();
    private static final AtomicInteger RANK = new AtomicInteger(
            Integer.MIN_VALUE + ThreadLocalRandom.current().nextInt(1_000_000));

    @DynamicPropertySource
    static void aiProperties(DynamicPropertyRegistry registry) {
        registry.add("app.ai.completion.base-url", OPENAI::baseUrl);
        registry.add("app.ai.embedding.base-url", OPENAI::baseUrl);
        registry.add("app.ai.completion.api-key", () -> "test-completion-key");
        registry.add("app.ai.embedding.api-key", () -> "test-embedding-key");
        registry.add("app.security.open-admin-endpoints", () -> "false");
        registry.add("meeple.rulebook.ingest-sweep-initial-delay-ms", () -> "86400000");
        registry.add("app.hydration.batch-delay-ms", () -> "0");
        registry.add("app.hydration.failure-backoff-ms", () -> "0");
    }

    @MockitoBean protected S3Client s3Client;
    @MockitoBean protected BggApiClient bggApiClient;
    @MockitoBean protected RuleBookOrgClient ruleBookOrgClient;
    @MockitoBean protected OnjRulebookClient onjRulebookClient;
    @MockitoBean protected SafePdfDownloader pdfDownloader;
    @MockitoBean protected BggRulebookClient bggRulebookClient;
    @MockitoBean protected DataSeedRunner dataSeedRunner;

    @Autowired protected MockMvc mvc;
    @Autowired protected JdbcTemplate jdbc;
    @Autowired protected StringRedisTemplate redis;
    @Autowired protected JwtUtil jwtUtil;

    private final List<UUID> createdGames = new ArrayList<>();
    private final List<UUID> createdUsers = new ArrayList<>();

    @BeforeEach
    void resetFakeOpenAi() {
        OPENAI.reset();
    }

    @AfterEach
    void cleanUpCreatedRows() {
        OPENAI.reset();
        for (UUID id : createdGames) {
            jdbc.update("DELETE FROM games WHERE id = ?", id);
            deleteRedisKeysMentioning(id);
        }
        for (UUID id : createdUsers) {
            jdbc.update("DELETE FROM notifications WHERE recipient_id = ?", id);
            jdbc.update("DELETE FROM users WHERE id = ?", id);
            deleteRedisKeysMentioning(id);
        }
        createdGames.clear();
        createdUsers.clear();
    }

    protected void deleteRedisKeysMentioning(UUID id) {
        Set<String> keys = redis.keys("*" + id + "*");
        if (keys != null && !keys.isEmpty()) {
            redis.delete(keys);
        }
    }

    // -------------------------------------------------------------------------
    // Users + auth
    // -------------------------------------------------------------------------

    protected UUID createUser() {
        return createUser("USER");
    }

    protected UUID createUser(String role) {
        UUID id = UUID.randomUUID();
        String suffix = id.toString().substring(0, 12).replace("-", "");
        jdbc.update("INSERT INTO users (id, username, email, role) VALUES (?, ?, ?, ?)",
                id, "t_" + suffix, "t_" + suffix + "@example.test", role);
        createdUsers.add(id);
        return id;
    }

    protected String usernameOf(UUID userId) {
        return jdbc.queryForObject("SELECT username FROM users WHERE id = ?", String.class, userId);
    }

    /** A real access token, as the web client sends it (httpOnly cookie). */
    protected Cookie auth(UUID userId) {
        return new Cookie("access_token", jwtUtil.generateAccessToken(userId, 0));
    }

    /** A real access token, as the mobile client sends it. */
    protected String bearer(UUID userId) {
        return "Bearer " + jwtUtil.generateAccessToken(userId, 0);
    }

    // -------------------------------------------------------------------------
    // Games
    // -------------------------------------------------------------------------

    protected GameSeed game(String name) {
        return new GameSeed(name);
    }

    /** Fluent builder for a games row (+ optional game_details row). */
    public final class GameSeed {
        private final String name;
        private long bggId = -ThreadLocalRandom.current().nextLong(1_000_000L, 9_000_000_000_000L);
        private Integer rank = RANK.getAndIncrement();
        private Integer minPlayers = 2;
        private Integer maxPlayers = 4;
        private Integer playTime = 60;
        private Integer usersRated;
        private Integer year;
        private BigDecimal rating;
        private String gameType = "boardgame";
        private String thumbnail;
        private String nameZh;
        private Instant hydrationAttemptedAt;
        private boolean withDetail;
        private String description;
        private BigDecimal complexity;
        private String[] mechanics = new String[0];
        private String[] categories = new String[0];
        private String[] families = new String[0];
        private Integer rankStrategy;
        private Integer rankParty;
        private Integer rankFamily;
        private Integer rankAbstract;
        private String bggUrl;

        private GameSeed(String name) {
            this.name = name;
        }

        public GameSeed bggId(long v) { this.bggId = v; return this; }
        public GameSeed rank(Integer v) { this.rank = v; return this; }
        public GameSeed players(Integer min, Integer max) { this.minPlayers = min; this.maxPlayers = max; return this; }
        public GameSeed playTime(Integer v) { this.playTime = v; return this; }
        public GameSeed usersRated(Integer v) { this.usersRated = v; return this; }
        public GameSeed year(Integer v) { this.year = v; return this; }
        public GameSeed rating(String v) { this.rating = v == null ? null : new BigDecimal(v); return this; }
        public GameSeed type(String v) { this.gameType = v; return this; }
        public GameSeed thumbnail(String v) { this.thumbnail = v; return this; }
        public GameSeed nameZh(String v) { this.nameZh = v; return this; }
        public GameSeed unhydrated() { this.minPlayers = null; this.maxPlayers = null; return this; }
        public GameSeed hydrationAttemptedAt(Instant v) { this.hydrationAttemptedAt = v; return this; }
        public GameSeed description(String v) { this.description = v; this.withDetail = true; return this; }
        public GameSeed complexity(String v) { this.complexity = new BigDecimal(v); this.withDetail = true; return this; }
        public GameSeed mechanics(String... v) { this.mechanics = v; this.withDetail = true; return this; }
        public GameSeed categories(String... v) { this.categories = v; this.withDetail = true; return this; }
        public GameSeed families(String... v) { this.families = v; this.withDetail = true; return this; }
        public GameSeed rankStrategy(Integer v) { this.rankStrategy = v; this.withDetail = true; return this; }
        public GameSeed rankParty(Integer v) { this.rankParty = v; this.withDetail = true; return this; }
        public GameSeed rankFamily(Integer v) { this.rankFamily = v; this.withDetail = true; return this; }
        public GameSeed rankAbstract(Integer v) { this.rankAbstract = v; this.withDetail = true; return this; }
        public GameSeed bggUrl(String v) { this.bggUrl = v; this.withDetail = true; return this; }
        public GameSeed withDetail() { this.withDetail = true; return this; }

        public long bggId() { return bggId; }

        public UUID insert() {
            UUID id = UUID.randomUUID();
            jdbc.update("""
                    INSERT INTO games (id, bgg_id, name_en, name_zh, rank, min_players, max_players, play_time,
                                       users_rated, year_published, bgg_rating, game_type, thumbnail_url,
                                       hydration_attempted_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    id, bggId, name, nameZh, rank, minPlayers, maxPlayers, playTime, usersRated, year, rating,
                    gameType, thumbnail, hydrationAttemptedAt == null ? null : Timestamp.from(hydrationAttemptedAt));
            createdGames.add(id);
            if (withDetail) {
                jdbc.update("""
                        INSERT INTO game_details (game_id, description, complexity, mechanics, categories, families,
                                                  rank_strategy, rank_party, rank_family, rank_abstract, bgg_url)
                        VALUES (?, ?, ?, ?::text[], ?::text[], ?::text[], ?, ?, ?, ?, ?)
                        """,
                        id, description, complexity, pgArray(mechanics), pgArray(categories), pgArray(families),
                        rankStrategy, rankParty, rankFamily, rankAbstract, bggUrl);
            }
            return id;
        }
    }

    /** Registers a game created by production code so it is cleaned up after the test. */
    protected void trackGame(UUID gameId) {
        createdGames.add(gameId);
    }

    protected static String pgArray(String... values) {
        StringBuilder sb = new StringBuilder("{");
        for (int i = 0; i < values.length; i++) {
            if (i > 0) sb.append(',');
            sb.append('"').append(values[i].replace("\"", "\\\"")).append('"');
        }
        return sb.append('}').toString();
    }

    // -------------------------------------------------------------------------
    // Rulebooks / chunks
    // -------------------------------------------------------------------------

    protected UUID insertRulebook(UUID gameId, String source, String status, Instant createdAt) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO game_rulebooks (id, game_id, source, status, pdf_url, created_at) VALUES (?, ?, ?, ?, ?, ?)",
                id, gameId, source, status, "https://cdn.1j1ju.com/" + id + ".pdf", Timestamp.from(createdAt));
        return id;
    }

    protected UUID insertUserRulebook(UUID gameId, UUID uploader, String status, Integer queuePosition) {
        UUID id = UUID.randomUUID();
        jdbc.update("""
                INSERT INTO game_rulebooks (id, game_id, source, status, storage_key, public_url, queue_position, uploaded_by)
                VALUES (?, ?, 'user', ?, ?, ?, ?, ?)
                """, id, gameId, status, "rulebooks/" + gameId + "/" + id + ".pdf",
                "https://r2.example.test/rulebooks/" + id + ".pdf", queuePosition, uploader);
        return id;
    }

    protected String rulebookStatus(UUID rulebookId) {
        return jdbc.queryForObject("SELECT status FROM game_rulebooks WHERE id = ?", String.class, rulebookId);
    }

    protected void insertChunk(UUID gameId, int index, String text, float[] embedding) {
        jdbc.update("INSERT INTO game_rules (game_id, chunk_index, chunk_text, embedding) VALUES (?, ?, ?, CAST(? AS vector))",
                gameId, index, text, com.meeplehearth.ai.service.EmbeddingService.toVectorString(embedding));
    }

    protected int chunkCount(UUID gameId) {
        Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM game_rules WHERE game_id = ?", Integer.class, gameId);
        return n == null ? 0 : n;
    }

    /** Makes the mocked R2 client serve {@code bytes} for any GetObject call. */
    protected void r2Serves(byte[] bytes) {
        when(s3Client.getObject(any(GetObjectRequest.class))).thenAnswer(inv -> new ResponseInputStream<>(
                GetObjectResponse.builder().contentLength((long) bytes.length).build(),
                AbortableInputStream.create(new ByteArrayInputStream(bytes))));
    }
}
