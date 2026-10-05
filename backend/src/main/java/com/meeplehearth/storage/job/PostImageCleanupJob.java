package com.meeplehearth.storage.job;

import org.springframework.beans.factory.annotation.Autowired;
import com.meeplehearth.common.job.JobLock;
import com.meeplehearth.storage.service.ObjectStorageService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Lazy;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.sql.Timestamp;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * {@code post_image_cleanup} (TECH_STACK_ADDITIONS section 21, FEATURES_COMPLETE section 5.3):
 * removes from R2 the images of posts soft-deleted more than 30 days ago, then drops their
 * {@code post_images} rows so they are not processed again. Reads the post tables natively and
 * never touches live posts. Daily at 04:00 UTC under {@code lock:post_image_cleanup}.
 *
 * <p>Only URLs pointing into this bucket are deleted from storage; rows with foreign URLs are
 * simply removed. If storage fails the rows stay and are retried the next day.
 */
@Component
@Lazy(false)
public class PostImageCleanupJob {

    private static final Logger log = LoggerFactory.getLogger(PostImageCleanupJob.class);
    static final String LOCK_NAME = "post_image_cleanup";
    private static final Duration LOCK_TTL = Duration.ofMinutes(30);
    static final Duration RETENTION = Duration.ofDays(30);
    static final int BATCH_SIZE = 500;

    private final JdbcTemplate jdbc;
    private final ObjectStorageService storage;
    private final JobLock jobLock;
    private final Clock clock;

    @Autowired
    public PostImageCleanupJob(JdbcTemplate jdbc, ObjectStorageService storage, JobLock jobLock) {
        this(jdbc, storage, jobLock, Clock.systemUTC());
    }

    PostImageCleanupJob(JdbcTemplate jdbc, ObjectStorageService storage, JobLock jobLock, Clock clock) {
        this.jdbc = jdbc;
        this.storage = storage;
        this.jobLock = jobLock;
        this.clock = clock;
    }

    @Scheduled(cron = "0 0 4 * * *", zone = "UTC")
    public void run() {
        jobLock.runWithLock(LOCK_NAME, LOCK_TTL, this::cleanUp);
    }

    /** Deletes images of long-deleted posts; returns the number of image rows removed. */
    public int cleanUp() {
        Timestamp cutoff = Timestamp.from(Instant.now(clock).minus(RETENTION));
        int removed = 0;
        while (true) {
            List<Map<String, Object>> rows = jdbc.queryForList("""
                    SELECT pi.id, pi.url FROM post_images pi
                    JOIN posts p ON p.id = pi.post_id
                    WHERE p.deleted_at IS NOT NULL AND p.deleted_at < ?
                    LIMIT ?""", cutoff, BATCH_SIZE);
            if (rows.isEmpty()) {
                break;
            }
            List<UUID> ids = new ArrayList<>(rows.size());
            List<String> keys = new ArrayList<>();
            for (Map<String, Object> row : rows) {
                ids.add((UUID) row.get("id"));
                storage.keyFromPublicUrl((String) row.get("url")).ifPresent(keys::add);
            }
            try {
                if (!keys.isEmpty()) {
                    storage.deleteKeys(keys);
                }
            } catch (RuntimeException e) {
                log.warn("Post image cleanup could not delete {} objects: {}", keys.size(),
                        e.getClass().getSimpleName());
                break;
            }
            for (UUID id : ids) {
                removed += jdbc.update("DELETE FROM post_images WHERE id = ?", id);
            }
            if (rows.size() < BATCH_SIZE) {
                break;
            }
        }
        if (removed > 0) {
            log.info("Post image cleanup removed {} images", removed);
        }
        return removed;
    }
}
