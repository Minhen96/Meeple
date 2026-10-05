package com.meeplehearth.notification.job;

import com.meeplehearth.common.job.JobLock;
import com.meeplehearth.notification.repository.NotificationRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;

/**
 * {@code notification_cleanup} (TECH_STACK_ADDITIONS section 21): daily at 03:00 UTC, deletes
 * notifications older than {@link #RETENTION} and rows soft-deleted more than
 * {@link #SOFT_DELETE_GRACE} ago, in batches, under the Redis lock {@code lock:notification_cleanup}.
 * Unread counters may drift by the deleted unread rows until their TTL expires.
 *
 * <p>Eagerly created ({@code @Lazy(false)}) so the {@code @Scheduled} method is registered under
 * {@code spring.main.lazy-initialization=true}.
 */
@Component
@Lazy(false)
public class NotificationCleanupJob {

    private static final Logger log = LoggerFactory.getLogger(NotificationCleanupJob.class);

    static final String LOCK_NAME = "notification_cleanup";
    static final Duration LOCK_TTL = Duration.ofHours(1);
    static final Duration RETENTION = Duration.ofDays(90);
    static final Duration SOFT_DELETE_GRACE = Duration.ofDays(1);
    static final int BATCH_SIZE = 5_000;

    private final JobLock jobLock;
    private final NotificationRepository notificationRepository;
    private final TransactionTemplate transactionTemplate;
    private final Clock clock;

    @Autowired
    public NotificationCleanupJob(JobLock jobLock, NotificationRepository notificationRepository,
                                  PlatformTransactionManager transactionManager) {
        this(jobLock, notificationRepository, transactionManager, Clock.systemUTC());
    }

    NotificationCleanupJob(JobLock jobLock, NotificationRepository notificationRepository,
                           PlatformTransactionManager transactionManager, Clock clock) {
        this.jobLock = jobLock;
        this.notificationRepository = notificationRepository;
        this.transactionTemplate = new TransactionTemplate(transactionManager);
        this.clock = clock;
    }

    @Scheduled(cron = "${meeple.notification.cleanup-cron:0 0 3 * * *}", zone = "UTC")
    public void run() {
        jobLock.runWithLock(LOCK_NAME, LOCK_TTL, () -> {
            try {
                int deleted = purge();
                log.info("Notification cleanup removed {} row(s)", deleted);
            } catch (RuntimeException e) {
                log.error("Notification cleanup failed", e);
            }
        });
    }

    /** Deletes every expired row, one committed batch at a time; returns the number deleted. */
    int purge() {
        Instant now = clock.instant();
        Instant createdBefore = now.minus(RETENTION);
        Instant deletedBefore = now.minus(SOFT_DELETE_GRACE);
        int total = 0;
        while (true) {
            Integer deleted = transactionTemplate.execute(status ->
                    notificationRepository.deleteExpiredBatch(createdBefore, deletedBefore, BATCH_SIZE));
            int n = deleted == null ? 0 : deleted;
            total += n;
            if (n < BATCH_SIZE) {
                return total;
            }
        }
    }
}
