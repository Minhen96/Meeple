package com.meeplehearth.ai.job;

import com.meeplehearth.ai.repository.GameRulebookRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.data.redis.core.script.RedisScript;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.time.Duration;
import java.util.List;
import java.util.UUID;

/**
 * Marks rulebooks stuck in 'ingesting' as 'failed'. Ingestion runs on an in-memory executor
 * after the approving transaction commits, so a restart loses queued tasks and the row would
 * otherwise stay 'ingesting' forever, blocking the game. Failed rows can be retried by an admin
 * (POST /api/v1/admin/rulebooks/{id}/retry) and are retried by the auto-fetch batch after its
 * back-off.
 *
 * <p>Eagerly created because the app runs with lazy initialisation; guarded by a Redis lock so
 * only one instance sweeps.
 */
@Component
@Lazy(false)
public class StaleRulebookIngestionSweeper {

    private static final Logger log = LoggerFactory.getLogger(StaleRulebookIngestionSweeper.class);
    static final String LOCK_KEY = "lock:rulebook-ingest-sweeper";
    static final Duration LOCK_TTL = Duration.ofMinutes(5);

    /** Delete the key only if it still holds our token (never release another instance's lock). */
    static final RedisScript<Long> RELEASE_SCRIPT = new DefaultRedisScript<>(
            "if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end",
            Long.class);

    private final GameRulebookRepository rulebookRepository;
    private final StringRedisTemplate redisTemplate;
    private final Clock clock;

    @Autowired
    public StaleRulebookIngestionSweeper(GameRulebookRepository rulebookRepository,
                                         StringRedisTemplate redisTemplate) {
        this(rulebookRepository, redisTemplate, Clock.systemUTC());
    }

    StaleRulebookIngestionSweeper(GameRulebookRepository rulebookRepository,
                                  StringRedisTemplate redisTemplate,
                                  Clock clock) {
        this.rulebookRepository = rulebookRepository;
        this.redisTemplate = redisTemplate;
        this.clock = clock;
    }

    @Scheduled(fixedDelayString = "${meeple.rulebook.ingest-sweep-interval-ms:900000}",
            initialDelayString = "${meeple.rulebook.ingest-sweep-initial-delay-ms:120000}")
    public void sweep() {
        String token = UUID.randomUUID().toString();
        if (!Boolean.TRUE.equals(redisTemplate.opsForValue().setIfAbsent(LOCK_KEY, token, LOCK_TTL))) {
            log.debug("Stale ingestion sweep skipped — another instance holds the lock");
            return;
        }
        try {
            int failed = rulebookRepository.markStaleIngestingFailed(
                    clock.instant().minus(RulebookAutoFetchJob.STALE_INGESTING_AFTER));
            if (failed > 0) {
                log.warn("Marked {} stalled rulebook ingestion(s) as failed", failed);
            }
        } catch (Exception e) {
            log.error("Stale ingestion sweep failed", e);
        } finally {
            try {
                redisTemplate.execute(RELEASE_SCRIPT, List.of(LOCK_KEY), token);
            } catch (Exception e) {
                log.warn("Failed to release ingestion sweeper lock; it will expire after {}", LOCK_TTL, e);
            }
        }
    }
}
