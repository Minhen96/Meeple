package com.meeplehearth.auth.service;

import com.meeplehearth.support.auth.AuthWebIntegrationTest;
import com.meeplehearth.user.entity.User;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.Duration;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/** Runs the cleanup job's DELETE against real refresh_tokens rows and its lock against real Redis. */
class RefreshTokenCleanupJobIntegrationTest extends AuthWebIntegrationTest {

    private static final String LOCK_KEY = "lock:refresh_token_cleanup_job";

    @Autowired private RefreshTokenCleanupJob job;

    private UUID insertToken(UUID userId, String label, String expiresOffset, String usedOffset) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at, used_at) VALUES (?, ?, ?, now() + "
                        + expiresOffset + ", " + (usedOffset == null ? "NULL" : "now() + " + usedOffset) + ")",
                id, userId, sha256(label + id));
        return id;
    }

    private List<UUID> remaining(UUID userId) {
        return jdbc.queryForList("SELECT id FROM refresh_tokens WHERE user_id = ?", UUID.class, userId);
    }

    @Test
    void purgesExpiredAndLongRotatedTokensButKeepsLiveOnes() {
        User user = persistUser(true);
        UUID live = insertToken(user.getId(), "live", "interval '10 days'", null);
        UUID recentlyRotated = insertToken(user.getId(), "recent", "interval '10 days'", "interval '-1 day'");
        UUID expired = insertToken(user.getId(), "expired", "interval '-1 minute'", null);
        UUID rotatedLongAgo = insertToken(user.getId(), "old", "interval '10 days'", "interval '-8 days'");

        job.purgeStaleTokens();

        // Recently rotated tokens are kept so their reuse can still be detected as theft
        assertThat(remaining(user.getId())).containsExactlyInAnyOrder(live, recentlyRotated)
                .doesNotContain(expired, rotatedLongAgo);
        assertThat(redis.hasKey(LOCK_KEY)).as("lock released").isFalse();
    }

    @Test
    void skipsWhileAnotherInstanceHoldsTheLock() {
        User user = persistUser(true);
        UUID expired = insertToken(user.getId(), "expired", "interval '-1 minute'", null);
        assertThat(redis.opsForValue().setIfAbsent(LOCK_KEY, "other-instance", Duration.ofMinutes(1))).isTrue();
        trackRedisKey(LOCK_KEY);

        job.purgeStaleTokens();

        assertThat(remaining(user.getId())).containsExactly(expired);
        // The other instance's lock is left alone
        assertThat(redis.opsForValue().get(LOCK_KEY)).isEqualTo("other-instance");
    }
}
