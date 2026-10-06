package com.meeplehearth.user.job;

import org.springframework.beans.factory.annotation.Autowired;
import com.meeplehearth.common.event.UserHardDeletedEvent;
import com.meeplehearth.common.job.JobLock;
import com.meeplehearth.storage.StorageKeys;
import com.meeplehearth.storage.service.ObjectStorageService;
import com.meeplehearth.user.AccountPolicy;
import com.meeplehearth.user.service.DataExportService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.context.annotation.Lazy;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

import java.sql.Timestamp;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Permanently removes accounts whose 30-day deletion grace period has passed (FEATURES_COMPLETE
 * section 1.6). Runs daily at 03:00 UTC under the {@code lock:account_hard_delete} job lock.
 *
 * <p>Per user, in one transaction: {@link UserHardDeletedEvent} is published (synchronous
 * listeners run inside it, after-commit listeners after it), then the user row is deleted; the
 * foreign keys cascade to every row that references the user. After the commit the user's R2
 * objects (avatars, uploads, data exports) are deleted best-effort. A failure on one user is
 * logged and the job moves on; that user is retried the next night.
 */
@Component
@Lazy(false)
public class AccountHardDeleteJob {

    private static final Logger log = LoggerFactory.getLogger(AccountHardDeleteJob.class);
    static final String LOCK_NAME = "account_hard_delete";
    private static final Duration LOCK_TTL = Duration.ofMinutes(30);
    static final int BATCH_SIZE = 200;

    private final JdbcTemplate jdbc;
    private final TransactionTemplate transactionTemplate;
    private final ApplicationEventPublisher eventPublisher;
    private final ObjectStorageService storage;
    private final JobLock jobLock;
    private final Clock clock;

    @Autowired
    public AccountHardDeleteJob(JdbcTemplate jdbc,
                                TransactionTemplate transactionTemplate,
                                ApplicationEventPublisher eventPublisher,
                                ObjectStorageService storage,
                                JobLock jobLock) {
        this(jdbc, transactionTemplate, eventPublisher, storage, jobLock, Clock.systemUTC());
    }

    AccountHardDeleteJob(JdbcTemplate jdbc,
                         TransactionTemplate transactionTemplate,
                         ApplicationEventPublisher eventPublisher,
                         ObjectStorageService storage,
                         JobLock jobLock,
                         Clock clock) {
        this.jdbc = jdbc;
        this.transactionTemplate = transactionTemplate;
        this.eventPublisher = eventPublisher;
        this.storage = storage;
        this.jobLock = jobLock;
        this.clock = clock;
    }

    @Scheduled(cron = "0 0 3 * * *", zone = "UTC")
    public void run() {
        jobLock.runWithLock(LOCK_NAME, LOCK_TTL, this::purgeExpiredAccounts);
    }

    /** Hard-deletes every account past its grace period; returns how many were removed. */
    public int purgeExpiredAccounts() {
        Instant cutoff = Instant.now(clock).minus(AccountPolicy.DELETION_GRACE);
        int removed = 0;
        List<UUID> batch;
        do {
            batch = jdbc.queryForList(
                    "SELECT id FROM users WHERE deleted_at IS NOT NULL AND deleted_at < ? ORDER BY deleted_at LIMIT ?",
                    UUID.class, Timestamp.from(cutoff), BATCH_SIZE);
            int removedInBatch = 0;
            for (UUID userId : batch) {
                if (hardDelete(userId, cutoff)) {
                    removedInBatch++;
                }
            }
            removed += removedInBatch;
            // Stop when a batch made no progress, so a persistently failing user cannot loop forever
            if (removedInBatch == 0) {
                break;
            }
        } while (batch.size() == BATCH_SIZE);
        if (removed > 0) {
            log.info("Account hard delete removed {} accounts", removed);
        }
        return removed;
    }

    private boolean hardDelete(UUID userId, Instant cutoff) {
        try {
            Boolean deleted = transactionTemplate.execute(status -> {
                // Lock the row and re-check the cutoff: a reactivation that committed meanwhile wins,
                // and one that arrives now waits for this transaction
                List<UUID> locked = jdbc.queryForList(
                        "SELECT id FROM users WHERE id = ? AND deleted_at IS NOT NULL AND deleted_at < ? FOR UPDATE",
                        UUID.class, userId, Timestamp.from(cutoff));
                if (locked.isEmpty()) {
                    return false;
                }
                eventPublisher.publishEvent(new UserHardDeletedEvent(userId));
                return jdbc.update("DELETE FROM users WHERE id = ?", userId) == 1;
            });
            if (!Boolean.TRUE.equals(deleted)) {
                return false;
            }
        } catch (RuntimeException e) {
            log.warn("Hard delete of account {} failed: {}", userId, e.getClass().getSimpleName(), e);
            return false;
        }
        storage.deletePrefixQuietly(StorageKeys.AVATARS_PREFIX + userId + "/");
        storage.deletePrefixQuietly(StorageKeys.userUploadPrefix(userId));
        storage.deletePrivatePrefixQuietly(DataExportService.EXPORT_PREFIX + userId + "/");
        return true;
    }
}
