package com.meeplehearth.ai.service;

import com.meeplehearth.ai.entity.GameRulebook;
import com.meeplehearth.ai.repository.GameRulebookRepository;
import com.meeplehearth.config.AppProperties;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.user.entity.User;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import java.io.IOException;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;

/**
 * Manages the user-upload queue and admin review flow for rulebook PDFs.
 *
 * Queue rules:
 *   - User upload → pending_review, queue_position = count of existing pending_review for same game
 *   - Admin approve → set target to ingesting, cancel all other pending_review for same game
 *   - Admin reject  → set target to rejected, decrement queue_position of remaining items
 *   - Admin upload  → auto-approved: set ingesting, trigger ingestion immediately
 */
@Service
public class RulebookQueueService {

    private static final Logger log = LoggerFactory.getLogger(RulebookQueueService.class);

    private static final int MAX_PDF_BYTES = 25 * 1024 * 1024; // 25 MB
    private static final int USER_DAILY_UPLOAD_LIMIT = 5;
    private static final byte[] PDF_MAGIC = new byte[]{0x25, 0x50, 0x44, 0x46}; // %PDF

    private final GameRulebookRepository rulebookRepository;
    private final RulebookIngestionService ingestionService;
    private final PdfValidationService pdfValidationService;
    private final S3Client s3Client;
    private final AppProperties appProperties;
    private final StringRedisTemplate redisTemplate;

    public RulebookQueueService(GameRulebookRepository rulebookRepository,
                                RulebookIngestionService ingestionService,
                                PdfValidationService pdfValidationService,
                                S3Client s3Client,
                                AppProperties appProperties,
                                StringRedisTemplate redisTemplate) {
        this.rulebookRepository = rulebookRepository;
        this.ingestionService = ingestionService;
        this.pdfValidationService = pdfValidationService;
        this.s3Client = s3Client;
        this.appProperties = appProperties;
        this.redisTemplate = redisTemplate;
    }

    // -------------------------------------------------------------------------
    // User upload
    // -------------------------------------------------------------------------

    /**
     * Handles a user PDF upload for a game.
     * Validates the file, rate-limits, runs LLM rulebook check, then starts
     * ingestion directly — no admin review queue needed.
     *
     * @return the saved GameRulebook (status = ingesting)
     * @throws ApiException with INVALID_RULEBOOK if the LLM rejects the PDF
     */
    @Transactional
    public GameRulebook handleUserUpload(Game game, User uploader, MultipartFile file) {
        byte[] bytes = validatePdf(file);
        checkUserRateLimit(uploader.getId());

        // LLM check: is this actually a rulebook for the game?
        if (!pdfValidationService.isRulebook(bytes, game.getNameEn())) {
            throw ApiException.badRequest("INVALID_RULEBOOK",
                    "This PDF does not appear to be a rulebook for \"" + game.getNameEn() + "\". Please upload the correct file.");
        }

        String key = "rulebooks/" + game.getId() + "/" + UUID.randomUUID() + ".pdf";
        String publicUrl = uploadToR2(key, bytes);

        // Cancel any existing pending_review — this upload supersedes them
        cancelAllPendingForGame(game.getId(), "Superseded by newer user upload");

        GameRulebook rulebook = new GameRulebook();
        rulebook.setGame(game);
        rulebook.setSource("user");
        rulebook.setStatus("ingesting");
        rulebook.setStorageKey(key);
        rulebook.setPublicUrl(publicUrl);
        rulebook.setUploadedBy(uploader);
        rulebookRepository.save(rulebook);

        ingestionService.ingestAsync(rulebook.getId());

        log.info("User '{}' uploaded validated rulebook for '{}' — ingestion started",
                uploader.getUsername(), game.getNameEn());
        return rulebook;
    }

    // -------------------------------------------------------------------------
    // Admin upload (auto-approved)
    // -------------------------------------------------------------------------

    /**
     * Admin uploads a PDF — bypasses review queue, ingestion starts immediately.
     *
     * @return the saved GameRulebook (status will become approved after ingestion)
     */
    @Transactional
    public GameRulebook handleAdminUpload(Game game, User admin, MultipartFile file) {
        byte[] bytes = validatePdf(file);

        String key = "rulebooks/" + game.getId() + "/" + UUID.randomUUID() + ".pdf";
        String publicUrl = uploadToR2(key, bytes);

        // Cancel any existing pending_review submissions — admin upload supersedes them
        cancelAllPendingForGame(game.getId(), "Admin upload superseded user submissions");

        GameRulebook rulebook = new GameRulebook();
        rulebook.setGame(game);
        rulebook.setSource("admin");
        rulebook.setStatus("ingesting");
        rulebook.setStorageKey(key);
        rulebook.setPublicUrl(publicUrl);
        rulebook.setUploadedBy(admin);
        rulebookRepository.save(rulebook);

        ingestionService.ingestAsync(rulebook.getId());

        log.info("Admin '{}' uploaded rulebook for '{}' — ingestion started",
                admin.getUsername(), game.getNameEn());
        return rulebook;
    }

    // -------------------------------------------------------------------------
    // Admin review: approve
    // -------------------------------------------------------------------------

    /**
     * Admin approves a pending_review rulebook.
     * Triggers ingestion and cancels all other pending submissions for the same game.
     */
    @Transactional
    public void approve(GameRulebook rulebook, User admin) {
        if (!"pending_review".equals(rulebook.getStatus())) {
            throw ApiException.badRequest("INVALID_STATUS", "Rulebook is not pending review");
        }

        // Cancel other pending submissions for this game first
        List<GameRulebook> others = rulebookRepository
                .findByGame_IdAndStatusOrderByQueuePositionAsc(rulebook.getGame().getId(), "pending_review");
        for (GameRulebook other : others) {
            if (!other.getId().equals(rulebook.getId())) {
                other.setStatus("rejected");
                other.setRejectReason("Another rulebook was approved for this game");
                other.setReviewedBy(admin);
                other.setReviewedAt(Instant.now());
                rulebookRepository.save(other);
            }
        }

        // Set to ingesting and trigger pipeline
        rulebook.setStatus("ingesting");
        rulebook.setReviewedBy(admin);
        rulebook.setReviewedAt(Instant.now());
        rulebookRepository.save(rulebook);

        ingestionService.ingestAsync(rulebook.getId());
        log.info("Admin '{}' approved rulebook {} for game '{}'",
                admin.getUsername(), rulebook.getId(), rulebook.getGame().getNameEn());
    }

    // -------------------------------------------------------------------------
    // Admin review: reject
    // -------------------------------------------------------------------------

    /**
     * Admin rejects a pending_review rulebook and compacts the queue.
     */
    @Transactional
    public void reject(GameRulebook rulebook, User admin, String reason) {
        if (!"pending_review".equals(rulebook.getStatus())) {
            throw ApiException.badRequest("INVALID_STATUS", "Rulebook is not pending review");
        }

        rulebook.setStatus("rejected");
        rulebook.setRejectReason(reason);
        rulebook.setReviewedBy(admin);
        rulebook.setReviewedAt(Instant.now());
        rulebookRepository.save(rulebook);

        // Compact queue — decrement positions of items that were behind the rejected one
        if (rulebook.getQueuePosition() != null) {
            List<GameRulebook> remaining = rulebookRepository
                    .findByGame_IdAndStatusOrderByQueuePositionAsc(rulebook.getGame().getId(), "pending_review");
            for (GameRulebook item : remaining) {
                if (item.getQueuePosition() != null && item.getQueuePosition() > rulebook.getQueuePosition()) {
                    item.setQueuePosition(item.getQueuePosition() - 1);
                    rulebookRepository.save(item);
                }
            }
        }

        log.info("Admin '{}' rejected rulebook {} for game '{}': {}",
                admin.getUsername(), rulebook.getId(), rulebook.getGame().getNameEn(), reason);
    }

    // -------------------------------------------------------------------------
    // Internal helpers
    // -------------------------------------------------------------------------

    private byte[] validatePdf(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw ApiException.badRequest("EMPTY_FILE", "No file provided");
        }
        if (file.getSize() > MAX_PDF_BYTES) {
            throw ApiException.badRequest("FILE_TOO_LARGE", "PDF must be under 25 MB");
        }
        byte[] bytes;
        try {
            bytes = file.getBytes();
        } catch (IOException e) {
            throw ApiException.badRequest("FILE_READ_ERROR", "Could not read uploaded file");
        }
        // Check PDF magic bytes: %PDF
        if (bytes.length < 4
                || bytes[0] != PDF_MAGIC[0]
                || bytes[1] != PDF_MAGIC[1]
                || bytes[2] != PDF_MAGIC[2]
                || bytes[3] != PDF_MAGIC[3]) {
            throw ApiException.badRequest("INVALID_PDF", "File is not a valid PDF");
        }
        return bytes;
    }

    private void checkUserRateLimit(UUID userId) {
        String date = LocalDate.now(ZoneOffset.UTC).toString();
        String key = "rl:rulebook-upload:" + userId + ":" + date;
        Long count = redisTemplate.opsForValue().increment(key);
        if (count == 1) {
            // Set TTL to end of day
            redisTemplate.expire(key, Duration.ofDays(1));
        }
        if (count != null && count > USER_DAILY_UPLOAD_LIMIT) {
            throw ApiException.badRequest("RATE_LIMIT_EXCEEDED",
                    "You can upload at most " + USER_DAILY_UPLOAD_LIMIT + " rulebooks per day");
        }
    }

    private String uploadToR2(String key, byte[] bytes) {
        AppProperties.R2 r2 = appProperties.getR2();
        s3Client.putObject(
                PutObjectRequest.builder()
                        .bucket(r2.getBucket())
                        .key(key)
                        .contentType("application/pdf")
                        .build(),
                RequestBody.fromBytes(bytes)
        );
        return r2.getPublicUrl() + "/" + key;
    }

    private void cancelAllPendingForGame(UUID gameId, String reason) {
        List<GameRulebook> pending = rulebookRepository
                .findByGame_IdAndStatusOrderByQueuePositionAsc(gameId, "pending_review");
        for (GameRulebook item : pending) {
            item.setStatus("rejected");
            item.setRejectReason(reason);
            rulebookRepository.save(item);
        }
    }

    /** Deletes the R2 object for a rulebook (used if upload needs to be rolled back). */
    public void deleteFromR2(String storageKey) {
        if (storageKey == null) return;
        try {
            s3Client.deleteObject(DeleteObjectRequest.builder()
                    .bucket(appProperties.getR2().getBucket())
                    .key(storageKey)
                    .build());
        } catch (Exception e) {
            log.warn("Failed to delete R2 object {}: {}", storageKey, e.getMessage());
        }
    }
}
