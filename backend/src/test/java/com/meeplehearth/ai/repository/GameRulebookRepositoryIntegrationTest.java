package com.meeplehearth.ai.repository;

import com.meeplehearth.game.entity.Game;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.domain.PageRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;

import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;
import java.util.stream.Collectors;

import static org.assertj.core.api.Assertions.assertThat;

/** Runs the auto-fetch selection and stale-ingestion queries against the real Postgres schema. */
@SpringBootTest
@Transactional
class GameRulebookRepositoryIntegrationTest {

    @Autowired private JdbcTemplate jdbc;
    @Autowired private GameRulebookRepository rulebookRepository;

    private final Instant now = Instant.now();
    private int nextRank = Integer.MIN_VALUE + ThreadLocalRandom.current().nextInt(1_000_000);

    private UUID game(String name) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO games (id, bgg_id, name_en, game_type, rank) VALUES (?, ?, ?, 'boardgame', ?)",
                id, -ThreadLocalRandom.current().nextInt(1, 1_000_000_000), name, nextRank++);
        return id;
    }

    private UUID rulebook(UUID gameId, String status, Instant createdAt) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO game_rulebooks (id, game_id, source, status, pdf_url, created_at) "
                        + "VALUES (?, ?, 'onj', ?, 'https://cdn.1j1ju.com/x.pdf', ?)",
                id, gameId, status, Timestamp.from(createdAt));
        return id;
    }

    private Set<UUID> selectable() {
        List<Game> games = rulebookRepository.findGamesWithoutApprovedRulebook(
                now.minus(Duration.ofHours(1)), now.minus(Duration.ofDays(7)), 3, PageRequest.of(0, 50));
        return games.stream().map(Game::getId).collect(Collectors.toSet());
    }

    @Test
    void failedRulebooksBackOffAndAreCappedPerGame() {
        UUID fresh = game("never tried");
        UUID recentFailure = game("failed yesterday");
        rulebook(recentFailure, "failed", now.minus(Duration.ofDays(1)));
        UUID oldFailure = game("failed long ago");
        rulebook(oldFailure, "failed", now.minus(Duration.ofDays(8)));
        UUID tooManyFailures = game("failed three times");
        for (int i = 0; i < 3; i++) {
            rulebook(tooManyFailures, "failed", now.minus(Duration.ofDays(30 + i)));
        }
        UUID approved = game("approved");
        rulebook(approved, "approved", now.minus(Duration.ofDays(2)));

        Set<UUID> selected = selectable();

        assertThat(selected).contains(fresh, oldFailure);
        assertThat(selected).doesNotContain(recentFailure, tooManyFailures, approved);
    }

    @Test
    void staleIngestingRowsAreMarkedFailed() {
        UUID gameId = game("stuck");
        UUID stale = rulebook(gameId, "ingesting", now.minus(Duration.ofHours(3)));
        UUID active = rulebook(gameId, "ingesting", now.minus(Duration.ofMinutes(5)));

        assertThat(rulebookRepository.markStaleIngestingFailed(now.minus(Duration.ofHours(1))))
                .isGreaterThanOrEqualTo(1);

        assertThat(jdbc.queryForObject("SELECT status FROM game_rulebooks WHERE id = ?", String.class, stale))
                .isEqualTo("failed");
        assertThat(jdbc.queryForObject("SELECT status FROM game_rulebooks WHERE id = ?", String.class, active))
                .isEqualTo("ingesting");
    }
}
