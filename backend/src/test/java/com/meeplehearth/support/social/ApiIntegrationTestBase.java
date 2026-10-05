package com.meeplehearth.support.social;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.meeplehearth.auth.util.JwtUtil;
import org.junit.jupiter.api.AfterEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.RequestPostProcessor;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;

/**
 * Base for end-to-end API tests: real security filter chain (JWT), controllers, services and the
 * real Postgres schema. Deliberately NOT {@code @Transactional}: every request commits like in
 * production (so lazy-loading outside a transaction fails exactly as it would live). Each test's
 * rows are tracked and removed in {@link #cleanUp()}; deleting the users and games cascades to
 * posts, friend requests, blocks, notifications, match requests and match groups. Hosted events
 * and comments are deleted explicitly first: their user foreign keys are ON DELETE SET NULL (V60).
 */
@SpringBootTest
@AutoConfigureMockMvc
public abstract class ApiIntegrationTestBase {

    @Autowired protected MockMvc mvc;
    @Autowired protected JdbcTemplate jdbc;
    @Autowired protected JwtUtil jwtUtil;
    @Autowired protected ObjectMapper objectMapper;

    private final List<UUID> createdUsers = new ArrayList<>();
    private final List<UUID> createdGames = new ArrayList<>();

    @AfterEach
    void cleanUp() {
        for (UUID id : createdUsers) {
            deleteUserRows(jdbc, id);
        }
        for (UUID id : createdGames) {
            jdbc.update("DELETE FROM games WHERE id = ?", id);
        }
        createdUsers.clear();
        createdGames.clear();
    }

    /** Deletes a test user with the events they host and their comments (kept by V60 otherwise). */
    public static void deleteUserRows(JdbcTemplate jdbc, UUID userId) {
        jdbc.update("DELETE FROM events WHERE host_id = ?", userId);
        jdbc.update("DELETE FROM post_comments WHERE author_id = ?", userId);
        jdbc.update("DELETE FROM users WHERE id = ?", userId);
    }

    // -------------------------------------------------------------------------
    // Seeding
    // -------------------------------------------------------------------------

    protected UUID user() {
        UUID id = UUID.randomUUID();
        String suffix = id.toString().replace("-", "").substring(0, 12);
        jdbc.update("INSERT INTO users (id, username, email, display_name) VALUES (?, ?, ?, ?)",
                id, "it_" + suffix, "it_" + suffix + "@example.test", "IT " + suffix);
        createdUsers.add(id);
        return id;
    }

    protected UUID game() {
        return game(null, null);
    }

    protected UUID game(Integer minPlayers, Integer maxPlayers) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO games (id, bgg_id, name_en, min_players, max_players) VALUES (?, ?, ?, ?, ?)",
                id, -ThreadLocalRandom.current().nextLong(1_000_000L, Long.MAX_VALUE / 2), "IT Game",
                minPlayers, maxPlayers);
        createdGames.add(id);
        return id;
    }

    protected UUID friends(UUID a, UUID b) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO friend_requests (id, sender_id, receiver_id, status) VALUES (?, ?, ?, 'ACCEPTED')",
                id, a, b);
        return id;
    }

    protected void block(UUID blocker, UUID blocked) {
        jdbc.update("INSERT INTO blocked_users (blocker_id, blocked_id) VALUES (?, ?)", blocker, blocked);
    }

    protected void softDeleteUser(UUID id) {
        jdbc.update("UPDATE users SET deleted_at = now() WHERE id = ?", id);
    }

    protected static Timestamp ts(Instant instant) {
        return Timestamp.from(instant);
    }

    // -------------------------------------------------------------------------
    // Auth
    // -------------------------------------------------------------------------

    /** Authenticates with a real signed access token in the Authorization header. */
    protected RequestPostProcessor as(UUID userId) {
        String token = jwtUtil.generateAccessToken(userId, 0);
        return request -> {
            request.addHeader("Authorization", "Bearer " + token);
            return request;
        };
    }

    // -------------------------------------------------------------------------
    // Assertions / reading
    // -------------------------------------------------------------------------

    protected JsonNode json(MvcResult result) throws Exception {
        return objectMapper.readTree(result.getResponse().getContentAsString());
    }

    protected String toJson(Object body) throws Exception {
        return objectMapper.writeValueAsString(body);
    }

    protected int count(String sql, Object... args) {
        Integer n = jdbc.queryForObject(sql, Integer.class, args);
        return n == null ? 0 : n;
    }

    protected String string(String sql, Object... args) {
        return jdbc.queryForObject(sql, String.class, args);
    }
}
