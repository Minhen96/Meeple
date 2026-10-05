package com.meeplehearth.event.service;

import com.meeplehearth.common.job.JobLock;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Lazy;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.time.Instant;

/**
 * Event background jobs (TECH_STACK_ADDITIONS section 21), each under a Redis lock so only one
 * instance runs it:
 * <ul>
 *   <li>{@code event_auto_complete}: every 30 minutes, lock TTL 25 minutes.</li>
 *   <li>{@code event_reminder}: hourly, lock TTL 55 minutes.</li>
 * </ul>
 * Cron schedules (not fixed delays) so nothing runs at startup; minutes are offset from :00 to
 * spread load. Eagerly created ({@code @Lazy(false)}) because the application runs with
 * {@code spring.main.lazy-initialization=true}, where a lazy bean's {@code @Scheduled} methods
 * would never be registered.
 */
@Component
@Lazy(false)
public class EventJobs {

    private static final Logger log = LoggerFactory.getLogger(EventJobs.class);

    static final String AUTO_COMPLETE_LOCK = "event_auto_complete";
    static final Duration AUTO_COMPLETE_LOCK_TTL = Duration.ofMinutes(25);
    static final String REMINDER_LOCK = "event_reminder";
    static final Duration REMINDER_LOCK_TTL = Duration.ofMinutes(55);

    private final EventLifecycleService lifecycleService;
    private final JobLock jobLock;

    public EventJobs(EventLifecycleService lifecycleService, JobLock jobLock) {
        this.lifecycleService = lifecycleService;
        this.jobLock = jobLock;
    }

    @Scheduled(cron = "${meeple.event.auto-complete-cron:0 4/30 * * * *}")
    public void autoCompleteEvents() {
        jobLock.runWithLock(AUTO_COMPLETE_LOCK, AUTO_COMPLETE_LOCK_TTL, () -> {
            try {
                int completed = lifecycleService.completeDueEvents(Instant.now());
                log.info("event_auto_complete: {} events completed", completed);
            } catch (RuntimeException e) {
                log.error("event_auto_complete failed", e);
            }
        });
    }

    @Scheduled(cron = "${meeple.event.reminder-cron:0 11 * * * *}")
    public void sendReminders() {
        jobLock.runWithLock(REMINDER_LOCK, REMINDER_LOCK_TTL, () -> {
            try {
                int reminded = lifecycleService.sendDueReminders(Instant.now());
                log.info("event_reminder: {} events reminded", reminded);
            } catch (RuntimeException e) {
                log.error("event_reminder failed", e);
            }
        });
    }
}
