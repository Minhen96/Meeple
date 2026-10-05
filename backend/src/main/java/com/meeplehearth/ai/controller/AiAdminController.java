package com.meeplehearth.ai.controller;

import com.meeplehearth.ai.client.BggRulebookClient;
import com.meeplehearth.ai.client.SafePdfDownloader;
import com.meeplehearth.ai.service.AiCompletionService;
import com.meeplehearth.ai.service.EmbeddingService;
import com.meeplehearth.config.AppProperties;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Admin-only AI endpoints.
 *
 * Secured via SecurityConfig: /api/v1/admin/** requires ROLE_ADMIN
 * (open in local dev when app.security.open-admin-endpoints=true).
 *
 * All outbound calls go through circuit-breaker-protected beans
 * (EmbeddingService / AiCompletionService → "openai", SafePdfDownloader →
 * "rulebookDownload", BggRulebookClient → "bgg").
 */
@RestController
@RequestMapping("/api/v1/admin")
public class AiAdminController {

    private static final String CDN_CATAN_PDF =
            "https://cdn.1j1ju.com/medias/7a/18/fd-catan-rulebook.pdf";

    private final BggRulebookClient bggRulebookClient;
    private final AppProperties appProperties;
    private final EmbeddingService embeddingService;
    private final AiCompletionService completionService;
    private final SafePdfDownloader pdfDownloader;

    public AiAdminController(BggRulebookClient bggRulebookClient,
                             AppProperties appProperties,
                             EmbeddingService embeddingService,
                             AiCompletionService completionService,
                             SafePdfDownloader pdfDownloader) {
        this.bggRulebookClient = bggRulebookClient;
        this.appProperties = appProperties;
        this.embeddingService = embeddingService;
        this.completionService = completionService;
        this.pdfDownloader = pdfDownloader;
    }

    // -------------------------------------------------------------------------
    // Probe 1 — OpenAI API
    // -------------------------------------------------------------------------

    /**
     * GET /api/v1/admin/test/ai
     *
     * Verifies that the configured AI provider keys and models respond correctly.
     * Works with any OpenAI-compatible provider (OpenAI, DeepSeek, Groq, Together, etc.).
     * Run this before building any AI feature.
     *
     * Pass conditions:
     *   embeddingDims = 1536  (text-embedding-3-small)
     *   completionResponse = non-empty string
     *
     * Set AI_COMPLETION_API_KEY (and optionally AI_EMBEDDING_API_KEY) in .env.local.
     */
    @GetMapping("/test/ai")
    public ResponseEntity<Map<String, Object>> probeAiProvider() {
        Map<String, Object> result = new LinkedHashMap<>();
        String completionKey = appProperties.getAi().getCompletion().getApiKey();

        result.put("completionBaseUrl", appProperties.getAi().getCompletion().getBaseUrl());
        result.put("embeddingBaseUrl", appProperties.getAi().getEmbedding().getBaseUrl());

        if (completionKey == null || completionKey.isBlank()) {
            result.put("ok", false);
            result.put("error", "AI_COMPLETION_API_KEY not set — add it to .env.local");
            return ResponseEntity.ok(result);
        }

        // --- Embedding probe ---
        long t0 = System.currentTimeMillis();
        try {
            float[] embedding = embeddingService.embed("test");
            int dims = embedding.length;
            result.put("embeddingModel", appProperties.getAi().getEmbedding().getModel());
            result.put("embeddingDims", dims);
            result.put("embeddingPass", dims == 1536);
            result.put("embeddingLatencyMs", System.currentTimeMillis() - t0);

        } catch (Exception e) {
            result.put("embeddingPass", false);
            result.put("embeddingError", e.getMessage());
        }

        // --- Completion probe ---
        t0 = System.currentTimeMillis();
        try {
            String reply = completionService.complete(
                    List.of(Map.of("role", "user", "content", "Reply with exactly one word: hello")), 10, 0.0);
            result.put("completionModel", appProperties.getAi().getCompletion().getModel());
            result.put("completionResponse", reply);
            result.put("completionPass", reply != null && !reply.isBlank());
            result.put("completionLatencyMs", System.currentTimeMillis() - t0);

        } catch (Exception e) {
            result.put("completionPass", false);
            result.put("completionError", e.getMessage());
        }

        boolean allPass = Boolean.TRUE.equals(result.get("embeddingPass"))
                && Boolean.TRUE.equals(result.get("completionPass"));
        result.put("ok", allPass);
        result.put("verdict", allPass
                ? "AI provider configured correctly. Safe to proceed."
                : "One or more checks failed. Fix before building AI features.");

        return ResponseEntity.ok(result);
    }

    // -------------------------------------------------------------------------
    // Probe 2 — CDN PDF download
    // -------------------------------------------------------------------------

    /**
     * GET /api/v1/admin/test/pdf-download
     *
     * Downloads the Catan rulebook from cdn.1j1ju.com (the CDN used by both
     * rule-book.org and en.1jour-1jeu.com) through the same SSRF-guarded,
     * size-capped downloader the ingestion pipeline uses.
     *
     * Pass conditions:
     *   downloadable = true
     *   isPdfMagicBytes = true (the downloader enforces PDF content)
     *   sizeBytes > 100_000   (a real PDF is at least ~100 KB)
     *
     * If this fails: the background job cannot auto-download rulebooks.
     */
    @GetMapping("/test/pdf-download")
    public ResponseEntity<Map<String, Object>> probePdfDownload() {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("url", CDN_CATAN_PDF);

        long t0 = System.currentTimeMillis();
        try {
            byte[] bytes = pdfDownloader.download(CDN_CATAN_PDF);
            long latency = System.currentTimeMillis() - t0;

            result.put("downloadable", true);
            result.put("sizeBytes", bytes.length);
            result.put("isPdfMagicBytes", true);
            result.put("latencyMs", latency);
            result.put("pass", bytes.length > 100_000);
            result.put("verdict", bytes.length > 100_000
                    ? "CDN PDF download works. Background job can proceed."
                    : "Downloaded but content looks too small — check sizeBytes.");

        } catch (Exception e) {
            result.put("downloadable", false);
            result.put("pass", false);
            result.put("error", e.getMessage());
            result.put("verdict", "CDN download failed. Background job will NOT work. " +
                    "Check if CDN blocks server-side requests.");
        }

        return ResponseEntity.ok(result);
    }

    // -------------------------------------------------------------------------
    // BGG probes (kept from previous verification step — BGG dropped as source
    // but probes remain useful for debugging)
    // -------------------------------------------------------------------------

    /** GET /api/v1/admin/test/bgg-rulebook/{bggId} */
    @GetMapping("/test/bgg-rulebook/{bggId}")
    public ResponseEntity<BggRulebookClient.BggFilesProbeResult> probeBggRulebook(
            @PathVariable long bggId) {
        return ResponseEntity.ok(bggRulebookClient.probe(bggId));
    }

    /** GET /api/v1/admin/test/bgg-rulebook/{bggId}/english */
    @GetMapping("/test/bgg-rulebook/{bggId}/english")
    public ResponseEntity<BggRulebookClient.BggFilesProbeResult> probeBggRulebookEnglish(
            @PathVariable long bggId) {
        return ResponseEntity.ok(bggRulebookClient.probe(bggId, "2184"));
    }

    /** GET /api/v1/admin/test/bgg-rulebook/{bggId}/resolve */
    @GetMapping("/test/bgg-rulebook/{bggId}/resolve")
    public ResponseEntity<Map<String, Object>> resolveRulebookUrl(@PathVariable long bggId) {
        BggRulebookClient.BggFilesProbeResult probe = bggRulebookClient.probe(bggId, "2184");

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("bggId", bggId);
        result.put("reachable", probe.reachable());
        result.put("totalRulebookCandidates", probe.rulebookCandidates().size());

        if (!probe.reachable()) {
            result.put("resolvedUrl", null);
            result.put("note", "BGG API not reachable: " + probe.error());
            return ResponseEntity.ok(result);
        }
        if (probe.rulebookCandidates().isEmpty()) {
            result.put("resolvedUrl", null);
            result.put("note", "No rulebook candidates on first page. Total: "
                    + probe.totalItems() + " files across " + probe.totalPages() + " pages.");
            return ResponseEntity.ok(result);
        }

        BggRulebookClient.BggFileEntry candidate = probe.rulebookCandidates().get(0);
        result.put("candidate", candidate);
        String resolvedUrl = bggRulebookClient.tryResolveDownloadUrl(candidate);
        result.put("resolvedUrl", resolvedUrl);
        result.put("note", resolvedUrl != null
                ? "Resolved. Verify manually that URL returns a PDF."
                : "Could not extract download URL — BGG may require auth.");
        return ResponseEntity.ok(result);
    }
}
