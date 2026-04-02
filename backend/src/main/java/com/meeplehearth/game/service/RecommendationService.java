package com.meeplehearth.game.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.meeplehearth.game.dto.GameSummaryResponse;
import com.meeplehearth.game.repository.GameRepository;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.*;

/**
 * Multi-signal game recommendation engine.
 *
 * Scoring weights:
 *   mechanic overlap (favorites) × 0.25
 *   mechanic overlap (played)    × 0.20
 *   category overlap             × 0.15
 *   friend play count            × 0.15
 *   friend own count             × 0.10
 *   normalized BGG rating        × 0.10
 *
 * Cold start (no favorites or played games): returns empty list — frontend falls back to sort=rank.
 * Cache: Redis key rec:{userId}, 1-hour TTL.
 */
@Service
public class RecommendationService {

    private static final String CACHE_KEY_PREFIX = "rec:";
    private static final Duration CACHE_TTL = Duration.ofHours(1);
    private static final int MAX_POOL_SIZE = 500; // Large enough pool for deep scrolling

    private final JdbcTemplate jdbcTemplate;
    private final GameRepository gameRepository;
    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public RecommendationService(JdbcTemplate jdbcTemplate,
                                 GameRepository gameRepository,
                                 StringRedisTemplate redisTemplate) {
        this.jdbcTemplate = jdbcTemplate;
        this.gameRepository = gameRepository;
        this.redisTemplate = redisTemplate;
    }

    // -------------------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------------------

    public org.springframework.data.domain.Page<GameSummaryResponse> getRecommended(UUID userId, org.springframework.data.domain.Pageable pageable) {
        String cacheKey = CACHE_KEY_PREFIX + userId;

        // 1. Get cached order of IDs (the "discovery pool")
        List<UUID> allIds = getCachedDiscoveryPool(userId, cacheKey);
        if (allIds.isEmpty()) {
            return org.springframework.data.domain.Page.empty(pageable);
        }

        // 2. Slice for current page
        int start = (int) pageable.getOffset();
        if (start >= allIds.size()) {
            return org.springframework.data.domain.Page.empty(pageable);
        }
        int end = Math.min(start + pageable.getPageSize(), allIds.size());
        List<UUID> pageIds = allIds.subList(start, end);

        // 3. Fetch summary details for this page
        List<GameSummaryResponse> content = fetchOrdered(pageIds);

        return new org.springframework.data.domain.PageImpl<>(content, pageable, allIds.size());
    }

    private List<UUID> getCachedDiscoveryPool(UUID userId, String cacheKey) {
        String cached = redisTemplate.opsForValue().get(cacheKey);
        if (cached != null) {
            try {
                return objectMapper.readValue(cached, new TypeReference<>() {});
            } catch (Exception ignored) {}
        }

        // Fresh score
        List<UUID> ids = scoreGames(userId);
        if (!ids.isEmpty()) {
            try {
                redisTemplate.opsForValue().set(cacheKey,
                        objectMapper.writeValueAsString(ids), CACHE_TTL);
            } catch (Exception ignored) {}
        }
        return ids;
    }

    /** Call this whenever the user's collection or play log changes. */
    public void invalidateCache(UUID userId) {
        redisTemplate.delete(CACHE_KEY_PREFIX + userId);
    }

    // -------------------------------------------------------------------------
    // Scoring — one native SQL query with inline taste profile + friend signals
    // -------------------------------------------------------------------------

    private static final String SCORE_SQL = """
            WITH taste AS (
                SELECT
                    array_agg(DISTINCT m) FILTER (WHERE ug.is_favorited = true)      AS fav_mechanics,
                    array_agg(DISTINCT m) FILTER (WHERE ug.play_count  > 0)           AS played_mechanics,
                    array_agg(DISTINCT c)                                              AS liked_categories
                FROM user_games ug
                JOIN game_details gd ON gd.game_id = ug.game_id
                LEFT JOIN LATERAL unnest(gd.mechanics)  AS m ON true
                LEFT JOIN LATERAL unnest(gd.categories) AS c ON true
                WHERE ug.user_id = ?
                  AND (ug.is_favorited = true OR ug.play_count > 0)
            ),
            friend_scores AS (
                SELECT
                    ug.game_id,
                    COUNT(DISTINCT CASE WHEN ug.play_count > 0   THEN ug.user_id END) AS friend_plays,
                    COUNT(DISTINCT CASE WHEN ug.is_owned  = true THEN ug.user_id END) AS friend_owns
                FROM user_games ug
                WHERE ug.user_id IN (
                    SELECT CASE WHEN sender_id = ? THEN receiver_id ELSE sender_id END
                    FROM friend_requests
                    WHERE (sender_id = ? OR receiver_id = ?) AND status = 'ACCEPTED'
                )
                GROUP BY ug.game_id
            )
            SELECT g.id::text
            FROM games g
            JOIN game_details gd ON gd.game_id = g.id
            LEFT JOIN friend_scores fs ON fs.game_id = g.id
            CROSS JOIN taste t
            WHERE g.game_type = 'boardgame'
              AND (
                gd.mechanics  && COALESCE(t.fav_mechanics,    '{}'::text[])
                OR gd.mechanics  && COALESCE(t.played_mechanics, '{}'::text[])
                OR gd.categories && COALESCE(t.liked_categories, '{}'::text[])
              )
              AND g.id NOT IN (
                SELECT game_id FROM user_games
                WHERE user_id = ? AND (is_owned = true OR is_favorited = true)
              )
            ORDER BY (
                cardinality(array(SELECT unnest(gd.mechanics)  INTERSECT SELECT unnest(COALESCE(t.fav_mechanics,    '{}'::text[])))) * 0.25
              + cardinality(array(SELECT unnest(gd.mechanics)  INTERSECT SELECT unnest(COALESCE(t.played_mechanics, '{}'::text[])))) * 0.20
              + cardinality(array(SELECT unnest(gd.categories) INTERSECT SELECT unnest(COALESCE(t.liked_categories, '{}'::text[])))) * 0.15
              + LEAST(COALESCE(fs.friend_plays, 0), 5) / 5.0 * 0.15
              + LEAST(COALESCE(fs.friend_owns,  0), 5) / 5.0 * 0.10
              + COALESCE(g.bgg_rating, 0) / 10.0 * 0.10
            ) DESC
            LIMIT ?
            """;

    private List<UUID> scoreGames(UUID userId) {
        // Parameters: userId ×5 (taste, friend CASE, friend WHERE ×2, excluded), limit
        return jdbcTemplate.query(
                SCORE_SQL,
                (rs, rowNum) -> UUID.fromString(rs.getString(1)),
                userId, userId, userId, userId, userId, MAX_POOL_SIZE
        );
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private List<GameSummaryResponse> fetchOrdered(List<UUID> ids) {
        if (ids.isEmpty()) return List.of();
        List<com.meeplehearth.game.entity.Game> games = gameRepository.findAllById(ids);
        Map<UUID, Integer> order = new HashMap<>();
        for (int i = 0; i < ids.size(); i++) order.put(ids.get(i), i);
        games.sort(Comparator.comparingInt(g -> order.getOrDefault(g.getId(), Integer.MAX_VALUE)));
        return games.stream().map(GameSummaryResponse::from).toList();
    }
}
