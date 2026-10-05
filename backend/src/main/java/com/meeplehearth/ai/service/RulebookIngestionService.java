package com.meeplehearth.ai.service;

import com.meeplehearth.ai.client.SafePdfDownloader;
import com.meeplehearth.ai.entity.GameRulebook;
import com.meeplehearth.ai.repository.GameRulebookRepository;
import com.meeplehearth.config.AppProperties;
import org.apache.pdfbox.Loader;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.text.PDFTextStripper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import software.amazon.awssdk.core.ResponseInputStream;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectResponse;

import java.io.IOException;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Downloads, chunks, and embeds a rulebook PDF into game_rules.
 *
 * Pipeline (steps 1–4 run OUTSIDE any DB transaction):
 * 1. Download PDF (R2 object for uploads, SSRF-guarded HTTPS download for CDN urls)
 * 2. PDFBox: extract full text
 * 3. Chunk: 375 words / 50-word overlap
 * 4. Embed each chunk (EmbeddingService → float[1536])
 * 5. One short transaction in {@link RulebookChunkWriter}: delete old chunks,
 *    insert new ones, mark approved
 *
 * Ingestion is triggered by {@link RulebookIngestionRequestedEvent}, handled only after
 * the transaction that set the rulebook to 'ingesting' has committed.
 */
@Service
public class RulebookIngestionService {

    private static final Logger log = LoggerFactory.getLogger(RulebookIngestionService.class);
    private static final int CHUNK_WORDS = 375;
    private static final int OVERLAP_WORDS = 50;
    private static final int MAX_PDF_BYTES = 50 * 1024 * 1024; // 50 MB
    private static final String INGEST_LOCK_PREFIX = "lock:rulebook-ingest:";
    private static final Duration INGEST_LOCK_TTL = Duration.ofMinutes(30);

    private final GameRulebookRepository rulebookRepository;
    private final RulebookChunkWriter chunkWriter;
    private final EmbeddingService embeddingService;
    private final HowToPlayExtractionService extractionService;
    private final SafePdfDownloader pdfDownloader;
    private final S3Client s3Client;
    private final AppProperties appProperties;
    private final StringRedisTemplate redisTemplate;

    public RulebookIngestionService(GameRulebookRepository rulebookRepository,
            RulebookChunkWriter chunkWriter,
            EmbeddingService embeddingService,
            HowToPlayExtractionService extractionService,
            SafePdfDownloader pdfDownloader,
            S3Client s3Client,
            AppProperties appProperties,
            StringRedisTemplate redisTemplate) {
        this.rulebookRepository = rulebookRepository;
        this.chunkWriter = chunkWriter;
        this.embeddingService = embeddingService;
        this.extractionService = extractionService;
        this.pdfDownloader = pdfDownloader;
        this.s3Client = s3Client;
        this.appProperties = appProperties;
        this.redisTemplate = redisTemplate;
    }

    // -------------------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------------------

    /**
     * Runs after the enqueuing transaction commits (or immediately if published
     * outside a transaction), on the async executor.
     */
    @Async
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onIngestionRequested(RulebookIngestionRequestedEvent event) {
        ingest(event.rulebookId());
    }

    /** Not transactional: network + embedding work happens with no DB transaction open. */
    public void ingest(UUID rulebookId) {
        String lockKey = INGEST_LOCK_PREFIX + rulebookId;
        if (!Boolean.TRUE.equals(redisTemplate.opsForValue().setIfAbsent(lockKey, "1", INGEST_LOCK_TTL))) {
            log.debug("Rulebook {} is already being ingested — skipping duplicate request", rulebookId);
            return;
        }
        try {
            GameRulebook rulebook = rulebookRepository.findByIdWithGame(rulebookId).orElse(null);
            if (rulebook == null) {
                log.warn("Rulebook {} not found — skipping ingestion", rulebookId);
                return;
            }
            if (!"ingesting".equals(rulebook.getStatus())) {
                log.debug("Rulebook {} has status '{}' — skipping ingestion", rulebookId, rulebook.getStatus());
                return;
            }
            runPipeline(rulebook);
        } finally {
            redisTemplate.delete(lockKey);
        }
    }

    private void runPipeline(GameRulebook rulebook) {
        UUID rulebookId = rulebook.getId();
        String gameName = rulebook.getGame().getNameEn();
        log.debug("Ingesting rulebook {} for game '{}'", rulebookId, gameName);

        try {
            // 1. Download PDF
            byte[] pdfBytes = fetchPdf(rulebook);
            if (pdfBytes == null) {
                log.warn("Rulebook {} has no downloadable source — marking failed", rulebookId);
                chunkWriter.markFailed(rulebookId);
                return;
            }

            // 2. Extract text
            String text = extractText(pdfBytes);
            if (text.isBlank()) {
                log.warn("PDF for rulebook {} produced no extractable text", rulebookId);
                chunkWriter.markFailed(rulebookId);
                return;
            }

            // 3. Chunk  4. Embed
            List<String> chunks = chunk(text);
            List<RulebookChunkWriter.EmbeddedChunk> embedded = new ArrayList<>(chunks.size());
            for (int i = 0; i < chunks.size(); i++) {
                String chunkText = chunks.get(i);
                float[] embedding = embeddingService.embed(chunkText);
                embedded.add(new RulebookChunkWriter.EmbeddedChunk(
                        chunkText, i, wordCount(chunkText), EmbeddingService.toVectorString(embedding)));
            }

            // 5. Atomic swap in one short transaction
            if (!chunkWriter.replaceChunks(rulebookId, embedded)) {
                log.info("Rulebook {} was superseded during ingestion — chunks discarded", rulebookId);
                return;
            }
            log.debug("Ingested {} chunks for game '{}'", embedded.size(), gameName);

            // 6. Re-generate How-to-Play from the fresh chunks
            extractionService.extractAsync(rulebook.getGame().getId(), rulebook.getGame());

        } catch (Exception e) {
            log.error("Ingestion failed for rulebook {}: {}", rulebookId, e.getMessage(), e);
            try {
                chunkWriter.markFailed(rulebookId);
            } catch (Exception ex) {
                log.error("Could not update rulebook {} status to failed: {}", rulebookId, ex.getMessage());
            }
        }
    }

    // -------------------------------------------------------------------------
    // PDF retrieval
    // -------------------------------------------------------------------------

    /**
     * User/admin uploads are read straight from R2 by storage key (no outbound HTTP);
     * auto-fetched rulebooks go through the SSRF-guarded downloader.
     */
    private byte[] fetchPdf(GameRulebook rulebook) throws IOException {
        if (rulebook.getStorageKey() != null && !rulebook.getStorageKey().isBlank()) {
            return readFromR2(rulebook.getStorageKey());
        }
        if (rulebook.getPdfUrl() != null && !rulebook.getPdfUrl().isBlank()) {
            return pdfDownloader.download(rulebook.getPdfUrl());
        }
        return null;
    }

    private byte[] readFromR2(String storageKey) throws IOException {
        GetObjectRequest request = GetObjectRequest.builder()
                .bucket(appProperties.getR2().getBucket())
                .key(storageKey)
                .build();
        try (ResponseInputStream<GetObjectResponse> in = s3Client.getObject(request)) {
            Long length = in.response().contentLength();
            if (length != null && length > MAX_PDF_BYTES) {
                throw new IOException("Stored PDF exceeds " + MAX_PDF_BYTES + " bytes");
            }
            byte[] bytes = in.readNBytes(MAX_PDF_BYTES + 1);
            if (bytes.length > MAX_PDF_BYTES) {
                throw new IOException("Stored PDF exceeds " + MAX_PDF_BYTES + " bytes");
            }
            return bytes;
        }
    }

    // -------------------------------------------------------------------------
    // Text extraction (PDFBox)
    // -------------------------------------------------------------------------

    private String extractText(byte[] pdfBytes) throws Exception {
        try (PDDocument doc = Loader.loadPDF(pdfBytes)) {
            PDFTextStripper stripper = new PDFTextStripper();
            String raw = stripper.getText(doc);
            return normalizeWhitespace(raw);
        }
    }

    private String normalizeWhitespace(String text) {
        return text
                .replaceAll("\\r\\n|\\r", "\n") // normalize line endings
                .replaceAll("[ \\t]+", " ") // collapse horizontal whitespace
                .replaceAll("\\n{3,}", "\n\n") // collapse excessive blank lines
                .strip();
    }

    // -------------------------------------------------------------------------
    // Chunking — 375 words / 50-word overlap
    // -------------------------------------------------------------------------

    List<String> chunk(String text) {
        String[] words = text.split("\\s+");
        List<String> chunks = new ArrayList<>();
        int step = CHUNK_WORDS - OVERLAP_WORDS; // 325

        for (int start = 0; start < words.length; start += step) {
            int end = Math.min(start + CHUNK_WORDS, words.length);
            chunks.add(String.join(" ", java.util.Arrays.copyOfRange(words, start, end)));
            if (end == words.length)
                break;
        }
        return chunks;
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private int wordCount(String text) {
        return text.isBlank() ? 0 : text.split("\\s+").length;
    }
}
