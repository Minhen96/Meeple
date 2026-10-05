package com.meeplehearth.integration;

import com.meeplehearth.match.service.MatchService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Duration;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Two members dismissing the last two slots of a match group at the same time. Needs real
 * committed transactions on separate connections, so this class is deliberately not
 * {@code @Transactional}; it cleans up its own rows.
 */
@SpringBootTest
class MatchDismissConcurrencyIntegrationTest {

    @Autowired private JdbcTemplate jdbc;
    @Autowired private MatchService matchService;
    @Autowired private PlatformTransactionManager transactionManager;

    private UUID userA;
    private UUID userB;
    private UUID gameId;
    private UUID groupId;
    private UUID requestA;
    private UUID requestB;
    private ExecutorService executor;

    @BeforeEach
    void seed() {
        executor = Executors.newFixedThreadPool(2);
        userA = user();
        userB = user();
        gameId = UUID.randomUUID();
        jdbc.update("INSERT INTO games (id, bgg_id, name_en) VALUES (?, ?, ?)",
                gameId, -ThreadLocalRandom.current().nextInt(1_000_000, Integer.MAX_VALUE), "Dismiss IT Game");
        groupId = UUID.randomUUID();
        jdbc.update("INSERT INTO match_groups (id, game_id, status) VALUES (?, ?, 'PENDING')", groupId, gameId);
        jdbc.update("INSERT INTO match_group_members (group_id, user_id) VALUES (?, ?), (?, ?)",
                groupId, userA, groupId, userB);
        requestA = UUID.randomUUID();
        requestB = UUID.randomUUID();
        jdbc.update("INSERT INTO match_requests (id, user_id, game_id, status) VALUES (?, ?, ?, 'MATCHED'), (?, ?, ?, 'MATCHED')",
                requestA, userA, gameId, requestB, userB, gameId);
    }

    @AfterEach
    void cleanUp() {
        executor.shutdownNow();
        jdbc.update("DELETE FROM match_requests WHERE game_id = ?", gameId);
        jdbc.update("DELETE FROM match_group_members WHERE group_id = ?", groupId);
        jdbc.update("DELETE FROM match_groups WHERE id = ?", groupId);
        jdbc.update("DELETE FROM games WHERE id = ?", gameId);
        jdbc.update("DELETE FROM users WHERE id IN (?, ?)", userA, userB);
    }

    @Test
    void secondDismisserWaitsForFirstAndDismissesGroup() throws Exception {
        CountDownLatch firstHoldsLock = new CountDownLatch(1);
        CountDownLatch releaseFirst = new CountDownLatch(1);

        // First dismisser, frozen mid-transaction: it has locked the group (as dismissMatch does)
        // and marked its own membership DISMISSED, but has not committed yet.
        TransactionTemplate tx = new TransactionTemplate(transactionManager);
        tx.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
        Future<?> first = executor.submit(() -> tx.executeWithoutResult(status -> {
            jdbc.queryForObject("SELECT id FROM match_groups WHERE id = ? FOR UPDATE", UUID.class, groupId);
            jdbc.update("UPDATE match_group_members SET status = 'DISMISSED' WHERE group_id = ? AND user_id = ?",
                    groupId, userA);
            firstHoldsLock.countDown();
            try {
                releaseFirst.await(30, TimeUnit.SECONDS);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }));
        assertThat(firstHoldsLock.await(30, TimeUnit.SECONDS)).isTrue();

        // Second dismisser must block on the group row lock instead of reading A as PENDING
        Future<?> second = executor.submit(() -> matchService.dismissMatch(userB, groupId));
        assertThatThrownBy(() -> second.get(Duration.ofMillis(750).toMillis(), TimeUnit.MILLISECONDS))
                .isInstanceOf(TimeoutException.class);

        releaseFirst.countDown();
        first.get(30, TimeUnit.SECONDS);
        second.get(30, TimeUnit.SECONDS);

        assertThat(jdbc.queryForObject("SELECT status FROM match_groups WHERE id = ?", String.class, groupId))
                .isEqualTo("DISMISSED");
        assertThat(jdbc.queryForObject(
                "SELECT COUNT(*) FROM match_requests WHERE id IN (?, ?) AND status = 'ACTIVE'",
                Integer.class, requestA, requestB)).isEqualTo(2);
    }

    @Test
    void sequentialDismissalsDismissGroupAndReactivateRequests() {
        matchService.dismissMatch(userA, groupId);
        assertThat(jdbc.queryForObject("SELECT status FROM match_groups WHERE id = ?", String.class, groupId))
                .isEqualTo("PENDING");

        matchService.dismissMatch(userB, groupId);
        assertThat(jdbc.queryForObject("SELECT status FROM match_groups WHERE id = ?", String.class, groupId))
                .isEqualTo("DISMISSED");
        assertThat(jdbc.queryForObject(
                "SELECT COUNT(*) FROM match_requests WHERE id IN (?, ?) AND status = 'ACTIVE'",
                Integer.class, requestA, requestB)).isEqualTo(2);
    }

    private UUID user() {
        UUID id = UUID.randomUUID();
        String suffix = id.toString().replace("-", "").substring(0, 12);
        jdbc.update("INSERT INTO users (id, username, email) VALUES (?, ?, ?)",
                id, "dm_" + suffix, "dm_" + suffix + "@example.test");
        return id;
    }
}
