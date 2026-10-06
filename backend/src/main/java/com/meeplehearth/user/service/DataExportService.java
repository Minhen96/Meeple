package com.meeplehearth.user.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.storage.service.ObjectStorageService;
import com.meeplehearth.user.dto.DataExportResponse;
import com.meeplehearth.user.entity.DataExportRequest;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.DataExportRequestRepository;
import com.meeplehearth.user.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.core.task.TaskExecutor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.time.Duration;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

/**
 * GDPR data export (FEATURES_COMPLETE section 1.6): POST /users/me/export answers 202 at once and
 * a background task builds a zip with one JSON document of the user's own data, stores it in the
 * private R2 bucket under {@code exports/<userId>/} ({@link ObjectStorageService#putPrivate}) and
 * emails a 7-day presigned download link. {@code DataExportCleanupJob} deletes the zip and marks the
 * request EXPIRED once the link has run out.
 *
 * <p>At most one export per user per {@link #COOLDOWN}: asking again returns the existing request.
 * Credentials (password hash, Google id, token version) never leave the server.
 */
@Service
public class DataExportService {

    private static final Logger log = LoggerFactory.getLogger(DataExportService.class);
    static final Duration COOLDOWN = Duration.ofHours(24);
    static final Duration LINK_VALIDITY = ObjectStorageService.MAX_PRESIGN;
    public static final String EXPORT_PREFIX = "exports/";

    /**
     * Each section is one query returning a JSON array of the user's rows ({@code ?} is the
     * user id). Only rows the user owns or authored, plus events they took part in.
     */
    static final Map<String, String> SECTIONS = sections();

    private final DataExportRequestRepository requestRepository;
    private final UserRepository userRepository;
    private final JdbcTemplate jdbc;
    private final ObjectStorageService storage;
    private final AccountMailer mailer;
    private final TaskExecutor executor;
    private final TransactionTemplate transactionTemplate;
    private final ObjectMapper objectMapper;

    public DataExportService(DataExportRequestRepository requestRepository,
                             UserRepository userRepository,
                             JdbcTemplate jdbc,
                             ObjectStorageService storage,
                             AccountMailer mailer,
                             @Qualifier("taskExecutor") TaskExecutor executor,
                             TransactionTemplate transactionTemplate,
                             ObjectMapper objectMapper) {
        this.requestRepository = requestRepository;
        this.userRepository = userRepository;
        this.jdbc = jdbc;
        this.storage = storage;
        this.mailer = mailer;
        this.executor = executor;
        this.transactionTemplate = transactionTemplate;
        this.objectMapper = objectMapper;
    }

    private static Map<String, String> sections() {
        Map<String, String> sections = new LinkedHashMap<>();
        sections.put("collection", """
                SELECT ug.*, g.name_en AS game_name FROM user_games ug
                JOIN games g ON g.id = ug.game_id WHERE ug.user_id = ? ORDER BY ug.added_at""");
        sections.put("playLogs", "SELECT * FROM play_logs WHERE user_id = ? ORDER BY played_at");
        sections.put("posts", """
                SELECT p.*, (SELECT COALESCE(json_agg(pi.url ORDER BY pi.display_order), '[]'::json)
                             FROM post_images pi WHERE pi.post_id = p.id) AS image_urls
                FROM posts p WHERE p.author_id = ? ORDER BY p.created_at""");
        sections.put("comments", "SELECT * FROM post_comments WHERE author_id = ? ORDER BY created_at");
        sections.put("eventsHosted", "SELECT * FROM events WHERE host_id = ? ORDER BY scheduled_at");
        sections.put("eventParticipation", """
                SELECT ep.*, e.title AS event_title, e.scheduled_at AS event_scheduled_at
                FROM event_participants ep JOIN events e ON e.id = ep.event_id
                WHERE ep.user_id = ? ORDER BY e.scheduled_at""");
        sections.put("friendRequests", """
                SELECT id, sender_id, receiver_id, status, created_at FROM friend_requests
                WHERE sender_id = ?1 OR receiver_id = ?1 ORDER BY created_at""");
        sections.put("notifications", "SELECT * FROM notifications WHERE recipient_id = ? ORDER BY created_at");
        sections.put("matchRequests", "SELECT * FROM match_requests WHERE user_id = ? ORDER BY created_at");
        return sections;
    }

    /** Starts an export, or returns the user's recent one (pending, running or completed in the last 24h). */
    @Transactional
    public DataExportResponse requestExport(UUID userId) {
        userRepository.findById(userId)
                .filter(u -> u.getDeletedAt() == null)
                .orElseThrow(() -> ApiException.notFound("USER_NOT_FOUND", "User not found"));

        Optional<DataExportRequest> recent = requestRepository.findFirstByUserIdOrderByCreatedAtDesc(userId)
                .filter(r -> r.getStatus() != DataExportRequest.Status.FAILED)
                .filter(r -> r.getCreatedAt().isAfter(Instant.now().minus(COOLDOWN)));
        if (recent.isPresent()) {
            return DataExportResponse.from(recent.get());
        }

        DataExportRequest request = new DataExportRequest();
        request.setUserId(userId);
        requestRepository.save(request);
        UUID requestId = request.getId();
        runAfterCommit(() -> executor.execute(() -> process(requestId)));
        return DataExportResponse.from(request);
    }

    private static void runAfterCommit(Runnable task) {
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    task.run();
                }
            });
        } else {
            task.run();
        }
    }

    /** Builds, stores and emails one export. Safe to call twice: only one caller claims the request. */
    public void process(UUID requestId) {
        Integer claimed = transactionTemplate.execute(status -> requestRepository.claim(requestId));
        if (claimed == null || claimed != 1) {
            return;
        }
        DataExportRequest request = requestRepository.findById(requestId).orElseThrow();
        try {
            User user = userRepository.findById(request.getUserId())
                    .filter(u -> u.getDeletedAt() == null)
                    .orElseThrow(() -> new IllegalStateException("User is no longer active"));
            byte[] zip = zip(buildExport(user));
            String key = EXPORT_PREFIX + user.getId() + "/" + requestId + ".zip";
            storage.putPrivate(key, zip, "application/zip");
            String link = storage.presignPrivateGet(key, LINK_VALIDITY);

            transactionTemplate.executeWithoutResult(status -> {
                DataExportRequest done = requestRepository.findById(requestId).orElseThrow();
                done.setStatus(DataExportRequest.Status.COMPLETED);
                done.setFileKey(key);
                done.setCompletedAt(Instant.now());
                requestRepository.save(done);
            });
            mailer.sendExportReady(user.getId(), user.getEmail(), user.getPreferredLanguage(), link, LINK_VALIDITY);
        } catch (RuntimeException | IOException e) {
            log.warn("Data export {} failed: {}", requestId, e.getClass().getSimpleName());
            transactionTemplate.executeWithoutResult(status -> requestRepository.findById(requestId).ifPresent(r -> {
                r.setStatus(DataExportRequest.Status.FAILED);
                r.setCompletedAt(Instant.now());
                requestRepository.save(r);
            }));
        }
    }

    /** The export document: profile plus every section, as a JSON tree. */
    JsonNode buildExport(User user) {
        ObjectNode root = objectMapper.createObjectNode();
        root.put("exportedAt", Instant.now().toString());
        ObjectNode profile = root.putObject("profile");
        profile.put("id", user.getId().toString());
        profile.put("username", user.getUsername());
        profile.put("email", user.getEmail());
        profile.put("displayName", user.getDisplayName());
        profile.put("bio", user.getBio());
        profile.put("location", user.getLocation());
        profile.put("avatarUrl", user.getAvatarUrl());
        profile.put("bggUsername", user.getBggUsername());
        profile.put("preferredLanguage", user.getPreferredLanguage());
        profile.put("timezone", user.getTimezone());
        profile.put("createdAt", user.getCreatedAt() == null ? null : user.getCreatedAt().toString());

        for (Map.Entry<String, String> section : SECTIONS.entrySet()) {
            root.set(section.getKey(), querySection(section.getValue(), user.getId()));
        }
        return root;
    }

    private JsonNode querySection(String sql, UUID userId) {
        boolean numbered = sql.contains("?1");
        String jdbcSql = "SELECT COALESCE(json_agg(t), '[]'::json)::text FROM (" + sql.replace("?1", "?") + ") t";
        Object[] args = numbered ? new Object[]{userId, userId} : new Object[]{userId};
        String json = jdbc.queryForObject(jdbcSql, String.class, args);
        try {
            return objectMapper.readTree(json == null ? "[]" : json);
        } catch (IOException e) {
            throw new IllegalStateException("Export section is not valid JSON", e);
        }
    }

    byte[] zip(JsonNode export) throws IOException {
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        try (ZipOutputStream zip = new ZipOutputStream(bytes)) {
            zip.putNextEntry(new ZipEntry("meeple-export.json"));
            zip.write(objectMapper.writerWithDefaultPrettyPrinter().writeValueAsBytes(export));
            zip.closeEntry();
        }
        return bytes.toByteArray();
    }
}
