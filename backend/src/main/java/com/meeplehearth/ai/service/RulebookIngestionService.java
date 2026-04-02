package com.meeplehearth.ai.service;

import com.meeplehearth.ai.entity.GameRulebook;
import com.meeplehearth.ai.entity.RuleChunk;
import com.meeplehearth.ai.repository.GameRulebookRepository;
import com.meeplehearth.ai.repository.RuleChunkRepository;
import org.apache.pdfbox.Loader;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.text.PDFTextStripper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.client.RestClient;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Downloads, chunks, and embeds a rulebook PDF into game_rules.
 *
 * Pipeline:
 * 1. Download PDF (CDN url or R2 public_url)
 * 2. PDFBox: extract full text
 * 3. Chunk: 375 words / 50-word overlap
 * 4. Embed each chunk (EmbeddingService → float[1536])
 * 5. Atomic swap: delete old chunks, bulk-insert new ones
 */
@Service
public class RulebookIngestionService {

    private static final Logger log = LoggerFactory.getLogger(RulebookIngestionService.class);
    private static final int CHUNK_WORDS = 375;
    private static final int OVERLAP_WORDS = 50;

    private final GameRulebookRepository rulebookRepository;
    private final RuleChunkRepository ruleChunkRepository;
    private final EmbeddingService embeddingService;
    private final HowToPlayExtractionService extractionService;
    private final RestClient httpClient;

    public RulebookIngestionService(GameRulebookRepository rulebookRepository,
            RuleChunkRepository ruleChunkRepository,
            EmbeddingService embeddingService,
            HowToPlayExtractionService extractionService) {
        this.rulebookRepository = rulebookRepository;
        this.ruleChunkRepository = ruleChunkRepository;
        this.embeddingService = embeddingService;
        this.extractionService = extractionService;

        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(15_000);
        factory.setReadTimeout(60_000);
        this.httpClient = RestClient.builder()
                .defaultHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Meeple/1.0")
                .requestFactory(factory)
                .build();
    }

    // -------------------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------------------

    @Async
    public void ingestAsync(UUID rulebookId) {
        rulebookRepository.findByIdWithGame(rulebookId).ifPresent(this::ingest);
    }

    @Transactional
    public void ingest(GameRulebook rulebook) {
        String downloadUrl = resolveDownloadUrl(rulebook);
        if (downloadUrl == null) {
            log.warn("Rulebook {} has no downloadable URL — skipping ingestion", rulebook.getId());
            return;
        }

        log.debug("Ingesting rulebook {} for game '{}' from {}",
                rulebook.getId(), rulebook.getGame().getNameEn(), downloadUrl);

        try {
            // 1. Download PDF
            byte[] pdfBytes = downloadPdf(downloadUrl);

            // 2. Extract text
            String text = extractText(pdfBytes);
            if (text.isBlank()) {
                log.warn("PDF for rulebook {} produced no extractable text", rulebook.getId());
                return;
            }

            // 3. Chunk
            List<String> chunks = chunk(text);

            // 4. Embed + build RuleChunk objects
            List<RuleChunk> ruleChunks = new ArrayList<>(chunks.size());
            for (int i = 0; i < chunks.size(); i++) {
                String chunkText = chunks.get(i);
                float[] embedding = embeddingService.embed(chunkText);

                RuleChunk rc = new RuleChunk();
                rc.setGame(rulebook.getGame());
                rc.setRulebookId(rulebook.getId());
                rc.setChunkText(chunkText);
                rc.setChunkIndex(i);
                rc.setTokenCount(wordCount(chunkText));
                rc.setEmbedding(EmbeddingService.toVectorString(embedding));
                ruleChunks.add(rc);
            }

            // 5. Atomic swap: delete old → insert new → mark approved
            ruleChunkRepository.deleteByGameId(rulebook.getGame().getId());
            ruleChunkRepository.saveAll(ruleChunks);
            rulebook.setStatus("approved");
            rulebookRepository.save(rulebook);

            log.debug("Ingested {} chunks for game '{}'", ruleChunks.size(), rulebook.getGame().getNameEn());

            // 6. Re-generate How-to-Play from the fresh chunks
            extractionService.extractAsync(rulebook.getGame().getId(), rulebook.getGame());

        } catch (Exception e) {
            log.error("Ingestion failed for rulebook {}: {}", rulebook.getId(), e.getMessage(), e);
        }
    }

    // -------------------------------------------------------------------------
    // PDF download
    // -------------------------------------------------------------------------

    private byte[] downloadPdf(String url) {
        byte[] bytes = httpClient.get()
                .uri(url)
                .retrieve()
                .body(byte[].class);
        if (bytes == null || bytes.length == 0)
            throw new RuntimeException("Empty PDF response from " + url);
        return bytes;
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

    private String resolveDownloadUrl(GameRulebook rulebook) {
        if (rulebook.getPdfUrl() != null && !rulebook.getPdfUrl().isBlank())
            return rulebook.getPdfUrl();
        if (rulebook.getPublicUrl() != null && !rulebook.getPublicUrl().isBlank())
            return rulebook.getPublicUrl();
        return null;
    }

    private int wordCount(String text) {
        return text.isBlank() ? 0 : text.split("\\s+").length;
    }
}
