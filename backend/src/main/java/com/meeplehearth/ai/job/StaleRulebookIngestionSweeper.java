package com.meeplehearth.ai.job;

import com.meeplehearth.ai.repository.GameRulebookRepository;
import com.meeplehearth.common.job.JobLock;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.time.Duration;

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
    /** Redis key {@code lock:rulebook-ingest-sweeper}. */
    static final String LOCK_NAME = "rulebook-ingest-sweeper";
    static final Duration LOCK_TTL = Duration.ofMinutes(5);

    private final GameRulebookRepository rulebookRepository;
    private final JobLock jobLock;
    private final Clock clock;

    @Autowired
    public StaleRulebookIngestionSweeper(GameRulebookRepository rulebookRepository,
                                         JobLock jobLock) {
        this(rulebookRepository, jobLock, Clock.systemUTC());
    }

    StaleRulebookIngestionSweeper(GameRulebookRepository rulebookRepository,
                                  JobLock jobLock,
                                  Clock clock) {
        this.rulebookRepository = rulebookRepository;
        this.jobLock = jobLock;
        this.clock = clock;
    }

    @Scheduled(fixedDelayString = "${meeple.rulebook.ingest-sweep-interval-ms:900000}",
            initialDelayString = "${meeple.rulebook.ingest-sweep-initial-delay-ms:120000}")
    public void sweep() {
        jobLock.runWithLock(LOCK_NAME, LOCK_TTL, () -> {
            try {
                int failed = rulebookRepository.markStaleIngestingFailed(
                        clock.instant().minus(RulebookAutoFetchJob.STALE_INGESTING_AFTER));
                if (failed > 0) {
                    log.warn("Marked {} stalled rulebook ingestion(s) as failed", failed);
                }
            } catch (Exception e) {
                log.error("Stale ingestion sweep failed", e);
            }
        });
    }
}
