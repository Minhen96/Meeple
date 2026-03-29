package com.meeplehearth.match.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Duration;

@Component
public class MatchScheduler {

    private static final Logger log = LoggerFactory.getLogger(MatchScheduler.class);
    private static final String LOCK_KEY = "lock:matching_job";

    private final MatchService matchService;
    private final StringRedisTemplate redisTemplate;

    public MatchScheduler(MatchService matchService, StringRedisTemplate redisTemplate) {
        this.matchService = matchService;
        this.redisTemplate = redisTemplate;
    }

    @Scheduled(fixedDelayString = "${meeple.match.interval-ms:1800000}")
    public void runMatchingJob() {
        Boolean locked = redisTemplate.opsForValue()
                .setIfAbsent(LOCK_KEY, "1", Duration.ofMinutes(5));

        if (!Boolean.TRUE.equals(locked)) {
            log.debug("Matching job skipped — another instance holds the lock");
            return;
        }

        try {
            log.info("Running matching job");
            matchService.runMatchingAlgorithm();
            log.info("Matching job complete");
        } catch (Exception e) {
            log.error("Matching job failed", e);
        } finally {
            redisTemplate.delete(LOCK_KEY);
        }
    }
}
