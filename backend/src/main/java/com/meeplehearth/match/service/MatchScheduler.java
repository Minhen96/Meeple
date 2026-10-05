package com.meeplehearth.match.service;

import com.meeplehearth.common.job.JobLock;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Lazy;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Duration;

/**
 * Eagerly created ({@code @Lazy(false)}) because the application runs with
 * {@code spring.main.lazy-initialization=true}; a lazy bean would never be instantiated
 * and its {@code @Scheduled} method would never be registered.
 */
@Component
@Lazy(false)
public class MatchScheduler {

    private static final Logger log = LoggerFactory.getLogger(MatchScheduler.class);
    /** Redis key {@code lock:matching_job}. */
    static final String LOCK_NAME = "matching_job";

    /** Comfortably above the expected runtime so the lock cannot lapse mid-run. */
    static final Duration LOCK_TTL = Duration.ofMinutes(20);

    private final MatchService matchService;
    private final JobLock jobLock;

    public MatchScheduler(MatchService matchService, JobLock jobLock) {
        this.matchService = matchService;
        this.jobLock = jobLock;
    }

    @Scheduled(fixedDelayString = "${meeple.match.interval-ms:1800000}")
    public void runMatchingJob() {
        jobLock.runWithLock(LOCK_NAME, LOCK_TTL, () -> {
            try {
                log.info("Running matching job");
                matchService.runMatchingAlgorithm();
                log.info("Matching job complete");
            } catch (Exception e) {
                log.error("Matching job failed", e);
            }
        });
    }
}
