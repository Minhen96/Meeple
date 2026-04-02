package com.meeplehearth.ai.controller;

import com.meeplehearth.ai.client.BggRulebookClient;
import com.meeplehearth.config.AppProperties;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.http.HttpHeaders;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Admin-only AI endpoints.
 *
 * Secured via SecurityConfig: /api/v1/admin/** requires ROLE_ADMIN
 * (open in local dev when app.security.open-admin-endpoints=true).
 */
@RestController
@RequestMapping("/api/v1/admin")
public class AiAdminController {

    private static final String CDN_CATAN_PDF =
            "https://cdn.1j1ju.com/medias/7a/18/fd-catan-rulebook.pdf";

    private final BggRulebookClient bggRulebookClient;
    private final AppProperties appProperties;
    private final RestClient completionClient;  // base URL = AI_COMPLETION_BASE_URL
    private final RestClient cdnClient;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public AiAdminController(BggRulebookClient bggRulebookClient, AppProperties appProperties) {
        this.bggRulebookClient = bggRulebookClient;
        this.appProperties = appProperties;

        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(10_000);
        factory.setReadTimeout(20_000);

        this.completionClient = RestClient.builder()
                .baseUrl(appProperties.getAi().getCompletion().getBaseUrl())
                .requestFactory(factory)
                .build();

        this.cdnClient = RestClient.builder()
                .requestFactory(factory)
                .defaultHeader("User-Agent",
                        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Meeple/1.0")
                .build();
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
        String embeddingKey = appProperties.getAi().getEmbedding().getApiKey();

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
            String embeddingBaseUrl = appProperties.getAi().getEmbedding().getBaseUrl();
            String embeddingModel = appProperties.getAi().getEmbedding().getModel();
            String effectiveEmbeddingKey = (embeddingKey != null && !embeddingKey.isBlank()) ? embeddingKey : completionKey;

            RestClient embeddingClient = RestClient.builder()
                    .baseUrl(embeddingBaseUrl)
                    .build();

            String embeddingBody = """
                    {"model":"%s","input":"test"}
                    """.formatted(embeddingModel);

            String embeddingResponse = embeddingClient.post()
                    .uri("/v1/embeddings")
                    .header(HttpHeaders.AUTHORIZATION, "Bearer " + effectiveEmbeddingKey)
                    .header(HttpHeaders.CONTENT_TYPE, "application/json")
                    .body(embeddingBody)
                    .retrieve()
                    .body(String.class);

            JsonNode root = objectMapper.readTree(embeddingResponse);
            int dims = root.path("data").get(0).path("embedding").size();
            result.put("embeddingModel", embeddingModel);
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
            String completionModel = appProperties.getAi().getCompletion().getModel();

            String completionBody = """
                    {
                      "model": "%s",
                      "messages": [{"role":"user","content":"Reply with exactly one word: hello"}],
                      "max_tokens": 10,
                      "temperature": 0
                    }
                    """.formatted(completionModel);

            String completionResponse = completionClient.post()
                    .uri("/v1/chat/completions")
                    .header(HttpHeaders.AUTHORIZATION, "Bearer " + completionKey)
                    .header(HttpHeaders.CONTENT_TYPE, "application/json")
                    .body(completionBody)
                    .retrieve()
                    .body(String.class);

            JsonNode root = objectMapper.readTree(completionResponse);
            String reply = root.path("choices").get(0).path("message").path("content").asText();
            result.put("completionModel", completionModel);
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
     * rule-book.org and en.1jour-1jeu.com) and checks whether server-side
     * downloads work without authentication.
     *
     * Pass conditions:
     *   downloadable = true
     *   contentType contains "pdf"
     *   sizeBytes > 100_000   (a real PDF is at least ~100 KB)
     *
     * If this fails: the background job cannot auto-download rulebooks.
     * We would need a different strategy (proxy, user agent rotation, etc.)
     */
    @GetMapping("/test/pdf-download")
    public ResponseEntity<Map<String, Object>> probePdfDownload() {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("url", CDN_CATAN_PDF);

        long t0 = System.currentTimeMillis();
        try {
            RestClient.ResponseSpec spec = cdnClient.get()
                    .uri(CDN_CATAN_PDF)
                    .retrieve();

            // Fetch as byte array to check real content
            byte[] bytes = spec.body(byte[].class);
            long latency = System.currentTimeMillis() - t0;

            if (bytes == null || bytes.length == 0) {
                result.put("downloadable", false);
                result.put("error", "Empty response body");
                return ResponseEntity.ok(result);
            }

            // Check PDF magic bytes: %PDF
            boolean isPdf = bytes.length >= 4
                    && bytes[0] == 0x25  // %
                    && bytes[1] == 0x50  // P
                    && bytes[2] == 0x44  // D
                    && bytes[3] == 0x46; // F

            result.put("downloadable", true);
            result.put("sizeBytes", bytes.length);
            result.put("isPdfMagicBytes", isPdf);
            result.put("latencyMs", latency);
            result.put("pass", isPdf && bytes.length > 100_000);
            result.put("verdict", (isPdf && bytes.length > 100_000)
                    ? "CDN PDF download works. Background job can proceed."
                    : "Downloaded but content looks wrong — check sizeBytes and isPdfMagicBytes.");

        } catch (RestClientException e) {
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
