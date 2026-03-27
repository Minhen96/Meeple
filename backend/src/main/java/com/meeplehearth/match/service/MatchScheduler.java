package com.meeplehearth.match.service;

import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

// Phase 2 — runs matching job periodically; uses Redis setIfAbsent distributed lock to prevent double-execution
@Component
public class MatchScheduler {

    @Scheduled(fixedDelayString = "${meeple.match.interval-ms:300000}")
    public void runMatchingJob() {
        // TODO: acquire Redis lock before executing
    }
}
