package com.meeplehearth.match.service;

import com.meeplehearth.common.job.JobLock;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Lazy;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.time.Instant;

/**
 * Matching jobs (TECH_STACK_ADDITIONS section 21), each under a Redis lock:
 * {@code matching_job} (every 30 minutes) and {@code match_request_expire} (hourly, lock TTL
 * 55 minutes).
 *
 * <p>Eagerly created ({@code @Lazy(false)}) because the application runs with
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

    /** Redis key {@code lock:match_request_expire}. */
    static final String EXPIRE_LOCK_NAME = "match_request_expire";
    static final Duration EXPIRE_LOCK_TTL = Duration.ofMinutes(55);

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

    @Scheduled(cron = "${meeple.match.request-expire-cron:0 23 * * * *}")
    public void expireStaleRequests() {
        jobLock.runWithLock(EXPIRE_LOCK_NAME, EXPIRE_LOCK_TTL, () -> {
            try {
                int expired = matchService.expireStaleRequests(Instant.now());
                log.info("match_request_expire: {} requests expired", expired);
            } catch (Exception e) {
                log.error("match_request_expire failed", e);
            }
        });
    }
}
