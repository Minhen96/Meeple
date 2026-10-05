package com.meeplehearth.ai.service;

import com.meeplehearth.ai.entity.GameRulebook;
import com.meeplehearth.ai.job.RulebookAutoFetchJob;
import com.meeplehearth.ai.repository.GameRulebookRepository;
import com.meeplehearth.config.AppProperties;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.user.entity.User;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import java.io.IOException;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Manages the user-upload queue and admin review flow for rulebook PDFs.
 *
 * Queue rules:
 *   - User upload   → LLM pre-check (fail closed) → pending_review,
 *                     queue_position = count of existing pending_review for same game.
 *                     NOT ingested until an admin approves it.
 *   - Admin approve → set target to ingesting, reject all other pending_review for same game,
 *                     ingestion starts after the transaction commits
 *   - Admin reject  → set target to rejected, decrement queue_position of remaining items
 *   - Admin upload  → auto-approved: set ingesting, ingestion starts after commit
 *
 * Slow external work (LLM validation, R2 upload) always happens BEFORE the short
 * persist transaction is opened.
 */
@Service
public class RulebookQueueService {

    private static final Logger log = LoggerFactory.getLogger(RulebookQueueService.class);

    private static final int MAX_PDF_BYTES = 25 * 1024 * 1024; // 25 MB
    private static final int USER_DAILY_UPLOAD_LIMIT = 5;
    private static final byte[] PDF_MAGIC = new byte[]{0x25, 0x50, 0x44, 0x46}; // %PDF

    private final GameRulebookRepository rulebookRepository;
    private final PdfValidationService pdfValidationService;
    private final S3Client s3Client;
    private final AppProperties appProperties;
    private final AiRateLimiter rateLimiter;
    private final ApplicationEventPublisher eventPublisher;
    private final TransactionTemplate transactionTemplate;

    public RulebookQueueService(GameRulebookRepository rulebookRepository,
                                PdfValidationService pdfValidationService,
                                S3Client s3Client,
                                AppProperties appProperties,
                                AiRateLimiter rateLimiter,
                                ApplicationEventPublisher eventPublisher,
                                PlatformTransactionManager transactionManager) {
        this.rulebookRepository = rulebookRepository;
        this.pdfValidationService = pdfValidationService;
        this.s3Client = s3Client;
        this.appProperties = appProperties;
        this.rateLimiter = rateLimiter;
        this.eventPublisher = eventPublisher;
        this.transactionTemplate = new TransactionTemplate(transactionManager);
    }

    // -------------------------------------------------------------------------
    // User upload
    // -------------------------------------------------------------------------

    /**
     * Handles a user PDF upload for a game.
     * Validates the file, rate-limits, runs the LLM rulebook pre-check, stores the PDF in R2,
     * and queues it for admin review. Nothing is ingested until an admin approves it.
     *
     * Not @Transactional: the LLM call and R2 upload run without a DB transaction;
     * only the final insert is transactional.
     *
     * @return the saved GameRulebook (status = pending_review)
     * @throws ApiException 400 INVALID_RULEBOOK if the LLM pre-check rejects the PDF,
     *                      429 RATE_LIMIT_EXCEEDED over the daily upload limit
     */
    public GameRulebook handleUserUpload(Game game, User uploader, MultipartFile file) {
        byte[] bytes = validatePdf(file);
        rateLimiter.checkDaily("rl:rulebook-upload:", uploader.getId(), USER_DAILY_UPLOAD_LIMIT,
                "RATE_LIMIT_EXCEEDED", "You can upload at most " + USER_DAILY_UPLOAD_LIMIT + " rulebooks per day");

        // LLM check: is this actually a rulebook for the game? (fails closed)
        if (!pdfValidationService.isRulebook(bytes, game.getNameEn())) {
            throw ApiException.badRequest("INVALID_RULEBOOK",
                    "This PDF could not be verified as a rulebook for \"" + game.getNameEn() + "\". Please upload the correct file.");
        }

        String key = "rulebooks/" + game.getId() + "/" + UUID.randomUUID() + ".pdf";
        String publicUrl = uploadToR2(key, bytes);

        try {
            GameRulebook saved = transactionTemplate.execute(status -> {
                int position = rulebookRepository.countByGame_IdAndStatus(game.getId(), "pending_review");

                GameRulebook rulebook = new GameRulebook();
                rulebook.setGame(game);
                rulebook.setSource("user");
                rulebook.setStatus("pending_review");
                rulebook.setQueuePosition(position);
                rulebook.setStorageKey(key);
                rulebook.setPublicUrl(publicUrl);
                rulebook.setUploadedBy(uploader);
                return rulebookRepository.save(rulebook);
            });

            log.info("User '{}' submitted rulebook for '{}' — queued for admin review",
                    uploader.getUsername(), game.getNameEn());
            return saved;
        } catch (RuntimeException e) {
            deleteFromR2(key);
            throw e;
        }
    }

    // -------------------------------------------------------------------------
    // Admin upload (auto-approved)
    // -------------------------------------------------------------------------

    /**
     * Admin uploads a PDF — bypasses review queue, ingestion starts right after commit.
     *
     * @return the saved GameRulebook (status will become approved after ingestion)
     */
    public GameRulebook handleAdminUpload(Game game, User admin, MultipartFile file) {
        byte[] bytes = validatePdf(file);

        String key = "rulebooks/" + game.getId() + "/" + UUID.randomUUID() + ".pdf";
        String publicUrl = uploadToR2(key, bytes);

        try {
            GameRulebook saved = transactionTemplate.execute(status -> {
                // Cancel any existing pending_review submissions — admin upload supersedes them
                cancelAllPendingForGame(game.getId(), admin, "Admin upload superseded user submissions");

                GameRulebook rulebook = new GameRulebook();
                rulebook.setGame(game);
                rulebook.setSource("admin");
                rulebook.setStatus("ingesting");
                rulebook.setStorageKey(key);
                rulebook.setPublicUrl(publicUrl);
                rulebook.setUploadedBy(admin);
                rulebook.setReviewedBy(admin);
                rulebook.setReviewedAt(Instant.now());
                GameRulebook persisted = rulebookRepository.save(rulebook);

                // Delivered to the ingestion listener only after this transaction commits
                eventPublisher.publishEvent(new RulebookIngestionRequestedEvent(persisted.getId()));
                return persisted;
            });

            log.info("Admin '{}' uploaded rulebook for '{}' — ingestion queued",
                    actorName(admin), game.getNameEn());
            return saved;
        } catch (RuntimeException e) {
            deleteFromR2(key);
            throw e;
        }
    }

    // -------------------------------------------------------------------------
    // Admin review: approve
    // -------------------------------------------------------------------------

    /**
     * Admin approves a pending_review rulebook.
     * Rejects all other pending submissions for the same game and triggers ingestion
     * once this transaction commits.
     */
    @Transactional
    public void approve(UUID rulebookId, User admin) {
        GameRulebook rulebook = rulebookRepository.findByIdWithGame(rulebookId)
                .orElseThrow(() -> ApiException.notFound("RULEBOOK_NOT_FOUND", "Rulebook not found"));
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

        // Set to ingesting; pipeline starts after commit
        rulebook.setStatus("ingesting");
        rulebook.setReviewedBy(admin);
        rulebook.setReviewedAt(Instant.now());
        rulebookRepository.save(rulebook);

        eventPublisher.publishEvent(new RulebookIngestionRequestedEvent(rulebook.getId()));
        log.info("Admin '{}' approved rulebook {} for game '{}'",
                actorName(admin), rulebook.getId(), rulebook.getGame().getNameEn());
    }

    // -------------------------------------------------------------------------
    // Admin: retry a failed or stalled ingestion
    // -------------------------------------------------------------------------

    /**
     * Re-queues a 'failed' rulebook, or an 'ingesting' one whose ingestion started longer than
     * {@link RulebookAutoFetchJob#STALE_INGESTING_AFTER} ago (its task was lost). Ingestion starts
     * after this transaction commits; reviewedAt is reset so the stale clock restarts.
     */
    @Transactional
    public void retry(UUID rulebookId, User admin) {
        GameRulebook rulebook = rulebookRepository.findByIdWithGame(rulebookId)
                .orElseThrow(() -> ApiException.notFound("RULEBOOK_NOT_FOUND", "Rulebook not found"));
        Instant now = Instant.now();
        Instant startedAt = rulebook.getReviewedAt() != null ? rulebook.getReviewedAt() : rulebook.getCreatedAt();
        boolean stale = "ingesting".equals(rulebook.getStatus())
                && startedAt != null
                && startedAt.isBefore(now.minus(RulebookAutoFetchJob.STALE_INGESTING_AFTER));
        if (!"failed".equals(rulebook.getStatus()) && !stale) {
            throw ApiException.badRequest("INVALID_STATUS", "Only failed or stalled rulebooks can be retried");
        }

        rulebook.setStatus("ingesting");
        rulebook.setReviewedBy(admin);
        rulebook.setReviewedAt(now);
        rulebookRepository.save(rulebook);

        eventPublisher.publishEvent(new RulebookIngestionRequestedEvent(rulebook.getId()));
        log.info("Admin '{}' retried ingestion of rulebook {} for game '{}'",
                actorName(admin), rulebook.getId(), rulebook.getGame().getNameEn());
    }

    // -------------------------------------------------------------------------
    // Admin review: reject
    // -------------------------------------------------------------------------

    /**
     * Admin rejects a pending_review rulebook and compacts the queue.
     */
    @Transactional
    public void reject(UUID rulebookId, User admin, String reason) {
        GameRulebook rulebook = rulebookRepository.findByIdWithGame(rulebookId)
                .orElseThrow(() -> ApiException.notFound("RULEBOOK_NOT_FOUND", "Rulebook not found"));
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

        log.info("Admin '{}' rejected rulebook {} for game '{}'",
                actorName(admin), rulebook.getId(), rulebook.getGame().getNameEn());
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

    /** Log label for the acting admin; null when admin endpoints are open in local dev. */
    private static String actorName(User admin) {
        return admin != null ? admin.getUsername() : "(unauthenticated)";
    }

    private void cancelAllPendingForGame(UUID gameId, User reviewer, String reason) {
        List<GameRulebook> pending = rulebookRepository
                .findByGame_IdAndStatusOrderByQueuePositionAsc(gameId, "pending_review");
        for (GameRulebook item : pending) {
            item.setStatus("rejected");
            item.setRejectReason(reason);
            item.setReviewedBy(reviewer);
            item.setReviewedAt(Instant.now());
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
