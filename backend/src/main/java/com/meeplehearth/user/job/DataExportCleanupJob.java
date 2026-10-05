package com.meeplehearth.user.job;

import com.meeplehearth.common.job.JobLock;
import com.meeplehearth.storage.service.ObjectStorageService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
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
 * {@code data_export_cleanup}: daily at 04:30 UTC under {@code lock:data_export_cleanup}, deletes
 * the zips of data exports completed more than {@link #RETENTION} ago (their emailed link has
 * expired) from the private bucket and marks the requests EXPIRED. If storage fails the requests
 * stay COMPLETED and are retried the next day.
 */
@Component
@Lazy(false)
public class DataExportCleanupJob {

    private static final Logger log = LoggerFactory.getLogger(DataExportCleanupJob.class);
    static final String LOCK_NAME = "data_export_cleanup";
    private static final Duration LOCK_TTL = Duration.ofMinutes(30);
    /** Matches the presigned link validity (DataExportService.LINK_VALIDITY). */
    static final Duration RETENTION = ObjectStorageService.MAX_PRESIGN;
    static final int BATCH_SIZE = 500;

    private final JdbcTemplate jdbc;
    private final ObjectStorageService storage;
    private final JobLock jobLock;
    private final Clock clock;

    @Autowired
    public DataExportCleanupJob(JdbcTemplate jdbc, ObjectStorageService storage, JobLock jobLock) {
        this(jdbc, storage, jobLock, Clock.systemUTC());
    }

    DataExportCleanupJob(JdbcTemplate jdbc, ObjectStorageService storage, JobLock jobLock, Clock clock) {
        this.jdbc = jdbc;
        this.storage = storage;
        this.jobLock = jobLock;
        this.clock = clock;
    }

    @Scheduled(cron = "0 30 4 * * *", zone = "UTC")
    public void run() {
        jobLock.runWithLock(LOCK_NAME, LOCK_TTL, this::cleanUp);
    }

    /** Expires every export older than the retention; returns how many requests were expired. */
    public int cleanUp() {
        Timestamp cutoff = Timestamp.from(Instant.now(clock).minus(RETENTION));
        int expired = 0;
        while (true) {
            List<Map<String, Object>> rows = jdbc.queryForList("""
                    SELECT id, file_key FROM data_export_requests
                    WHERE status = 'COMPLETED' AND completed_at < ?
                    ORDER BY completed_at LIMIT ?""", cutoff, BATCH_SIZE);
            if (rows.isEmpty()) {
                break;
            }
            List<UUID> ids = new ArrayList<>(rows.size());
            List<String> keys = new ArrayList<>();
            for (Map<String, Object> row : rows) {
                ids.add((UUID) row.get("id"));
                String key = (String) row.get("file_key");
                if (key != null && !key.isBlank()) {
                    keys.add(key);
                }
            }
            try {
                if (!keys.isEmpty()) {
                    storage.deletePrivateKeys(keys);
                }
            } catch (RuntimeException e) {
                log.warn("Data export cleanup could not delete {} objects: {}", keys.size(),
                        e.getClass().getSimpleName());
                break;
            }
            for (UUID id : ids) {
                expired += jdbc.update("UPDATE data_export_requests SET status = 'EXPIRED', file_key = NULL"
                        + " WHERE id = ? AND status = 'COMPLETED'", id);
            }
            if (rows.size() < BATCH_SIZE) {
                break;
            }
        }
        if (expired > 0) {
            log.info("Data export cleanup expired {} exports", expired);
        }
        return expired;
    }
}
