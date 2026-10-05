package com.meeplehearth.ai.client;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.io.IOException;
import java.net.HttpURLConnection;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * Probes the BGG (api.geekdo.com) files endpoint to find rulebook PDFs.
 *
 * Verified response shape (bggId=13, Catan):
 *   { "files": [ { "filepageid", "fileid", "filename", "size", "title",
 *                  "language", "href", "postdate", ... } ],
 *     "config": { "endpage", "numitems" } }
 *
 * Notable: BGG has no "filetype" field — we infer from filename (.pdf) + title.
 * BGG has no direct download URL — href is a file-page path (/filepage/{id}/slug).
 * We try to resolve the actual file URL via a HEAD/GET on that filepage.
 *
 * All outbound calls are guarded by the "bgg" circuit breaker. Redirects are not
 * followed, and resolved URLs must pass the {@link RulebookUrlValidator} allowlist.
 */
@Component
public class BggRulebookClient {

    private static final Logger log = LoggerFactory.getLogger(BggRulebookClient.class);
    private static final int TIMEOUT_MS = 12_000;

    // Language IDs from BGG config — English = 2184
    private static final String ENGLISH_LANGUAGE_ID = "2184";

    private final RestClient bggApiClient;
    private final RestClient bggWebClient;
    private final ObjectMapper objectMapper = new ObjectMapper();
    private final RulebookUrlValidator urlValidator;

    public BggRulebookClient(RulebookUrlValidator urlValidator) {
        this.urlValidator = urlValidator;

        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory() {
            @Override
            protected void prepareConnection(HttpURLConnection connection, String httpMethod) throws IOException {
                super.prepareConnection(connection, httpMethod);
                connection.setInstanceFollowRedirects(false);
            }
        };
        factory.setConnectTimeout(TIMEOUT_MS);
        factory.setReadTimeout(TIMEOUT_MS);

        this.bggApiClient = RestClient.builder()
                .baseUrl("https://api.geekdo.com")
                .requestFactory(factory)
                .defaultHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Meeple/1.0")
                .defaultHeader("Accept", "application/json")
                .build();

        // For resolving filepage download links
        this.bggWebClient = RestClient.builder()
                .baseUrl("https://boardgamegeek.com")
                .requestFactory(factory)
                .defaultHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Meeple/1.0")
                .defaultHeader("Accept", "text/html,application/xhtml+xml,application/pdf")
                .build();
    }

    // -------------------------------------------------------------------------
    // Probe — returns full picture for verification

    @CircuitBreaker(name = "bgg", fallbackMethod = "probeFallback")
    public BggFilesProbeResult probe(long bggId) {
        return fetchPage(bggId, 1, null);
    }

    @SuppressWarnings("unused")
    private BggFilesProbeResult probeFallback(long bggId, Throwable t) {
        log.warn("BGG files API unavailable for bggId={}: {}", bggId, t.getMessage());
        return BggFilesProbeResult.error(bggId, "BGG unavailable: " + t.getMessage());
    }

    /**
     * Probe with language filter.
     * languageId: "2184"=English, "2181"=Chinese, null=all languages
     */
    @CircuitBreaker(name = "bgg", fallbackMethod = "probeFallback")
    public BggFilesProbeResult probe(long bggId, String languageId) {
        return fetchPage(bggId, 1, languageId);
    }

    @SuppressWarnings("unused")
    private BggFilesProbeResult probeFallback(long bggId, String languageId, Throwable t) {
        log.warn("BGG files API unavailable for bggId={}: {}", bggId, t.getMessage());
        return BggFilesProbeResult.error(bggId, "BGG unavailable: " + t.getMessage());
    }

    // -------------------------------------------------------------------------
    // Resolve — find the best English rulebook PDF and return its download URL

    /**
     * Searches up to maxPages pages (10 files each) for an English PDF that
     * looks like a rulebook. Returns the download URL if found, else empty.
     *
     * Used by the background ingestion job once the probe verifies the API works.
     */
    @CircuitBreaker(name = "bgg", fallbackMethod = "resolveRulebookUrlFallback")
    public Optional<String> resolveRulebookUrl(long bggId, int maxPages) {
        for (int page = 1; page <= maxPages; page++) {
            BggFilesProbeResult result = fetchPage(bggId, page, ENGLISH_LANGUAGE_ID);
            if (!result.reachable()) break;

            for (BggFileEntry entry : result.rulebookCandidates()) {
                String url = resolveDownloadUrlInternal(entry);
                if (url != null) return Optional.of(url);
            }

            // No more pages
            if (result.totalPages() > 0 && page >= result.totalPages()) break;
        }
        return Optional.empty();
    }

    @SuppressWarnings("unused")
    private Optional<String> resolveRulebookUrlFallback(long bggId, int maxPages, Throwable t) {
        log.warn("BGG rulebook resolution unavailable for bggId={}: {}", bggId, t.getMessage());
        return Optional.empty();
    }

    // -------------------------------------------------------------------------

    /** HTTP failures propagate so the calling public method's circuit breaker records them. */
    private BggFilesProbeResult fetchPage(long bggId, int page, String languageId) {
        String uri = languageId != null
                ? "/api/files?objecttype=thing&objectid={id}&sort=recent&start=0&pageid={page}&languageid={lang}"
                : "/api/files?objecttype=thing&objectid={id}&sort=recent&start=0&pageid={page}";

        String rawJson = languageId != null
                ? bggApiClient.get().uri(uri, bggId, page, languageId).retrieve().body(String.class)
                : bggApiClient.get().uri(uri, bggId, page).retrieve().body(String.class);

        if (rawJson == null || rawJson.isBlank()) {
            return BggFilesProbeResult.error(bggId, "Empty response from BGG");
        }

        try {
            JsonNode root = objectMapper.readTree(rawJson);
            List<BggFileEntry> all = new ArrayList<>();
            List<BggFileEntry> rulebooks = new ArrayList<>();

            JsonNode filesNode = root.path("files");
            if (filesNode.isArray()) {
                for (JsonNode node : filesNode) {
                    BggFileEntry entry = parseEntry(node);
                    all.add(entry);
                    if (isRulebookCandidate(entry)) rulebooks.add(entry);
                }
            }

            int totalPages = root.path("config").path("endpage").asInt(0);
            int totalItems = root.path("config").path("numitems").asInt(0);

            return new BggFilesProbeResult(bggId, true, null, all, rulebooks, totalPages, totalItems, rawJson);

        } catch (Exception e) {
            log.warn("Failed to parse BGG files response for bggId={}: {}", bggId, e.getMessage());
            return new BggFilesProbeResult(bggId, true, "Parse error: " + e.getMessage(),
                    List.of(), List.of(), 0, 0, rawJson);
        }
    }

    /**
     * BGG doesn't expose a direct file URL in the API response.
     * href is a relative path like /filepage/317826/catan-rules-summary-...
     *
     * Strategy: GET boardgamegeek.com{href} (redirects are not followed) and, if
     * BGG serves the filepage HTML, extract the download link from it.
     *
     * Returns the resolved URL if it looks like a direct PDF link on an
     * allowlisted host, else null.
     */
    @CircuitBreaker(name = "bgg", fallbackMethod = "tryResolveDownloadUrlFallback")
    public String tryResolveDownloadUrl(BggFileEntry entry) {
        return resolveDownloadUrlInternal(entry);
    }

    @SuppressWarnings("unused")
    private String tryResolveDownloadUrlFallback(BggFileEntry entry, Throwable t) {
        log.debug("Could not resolve download URL for fileid={}: {}", entry.fileid(), t.getMessage());
        return null;
    }

    /** HTTP failures propagate so the calling public method's circuit breaker records them. */
    private String resolveDownloadUrlInternal(BggFileEntry entry) {
        String href = entry.href();
        // Only relative BGG paths — never let API data point this client at another host
        if (href == null || !href.startsWith("/") || href.startsWith("//")) return null;
        // Only attempt PDFs — skip images, docs, etc.
        if (!isPdfFilename(entry.filename())) return null;

        String response = bggWebClient.get()
                .uri(href)
                .retrieve()
                .body(String.class);

        if (response == null) return null;

        String resolved;
        if (response.contains("<html") || response.contains("<!DOCTYPE")) {
            // BGG returned the filepage HTML — look for the download link
            resolved = extractDownloadLinkFromHtml(response, href);
        } else {
            // Not HTML — BGG streamed the file itself, so the filepage URL is the download URL
            resolved = "https://boardgamegeek.com" + href;
        }
        return urlValidator.isAllowedSyntax(resolved) ? resolved : null;
    }

    /**
     * Extracts the actual file download link from a BGG filepage HTML.
     * BGG filepage contains a link like:
     *   <a ... href="/dl/filepage/{filepageid}/filename.pdf">Download</a>
     * or a cf.geekdo-images.com URL.
     */
    private String extractDownloadLinkFromHtml(String html, String originalHref) {
        // Look for /dl/ download links
        int dlIdx = html.indexOf("\"/dl/");
        if (dlIdx >= 0) {
            int end = html.indexOf("\"", dlIdx + 1);
            if (end > dlIdx) {
                return "https://boardgamegeek.com" + html.substring(dlIdx + 1, end);
            }
        }
        // Look for cf.geekdo-images.com PDF links
        int cfIdx = html.indexOf("cf.geekdo-images.com");
        if (cfIdx >= 0) {
            int start = html.lastIndexOf("\"", cfIdx);
            int end   = html.indexOf("\"", cfIdx);
            if (start >= 0 && end > start) {
                String url = html.substring(start + 1, end);
                if (url.contains(".pdf")) return url;
            }
        }
        // Fallback: return the filepage URL itself — ingestion job can try streaming it
        return "https://boardgamegeek.com" + originalHref;
    }

    // -------------------------------------------------------------------------

    private BggFileEntry parseEntry(JsonNode n) {
        return new BggFileEntry(
                text(n, "filepageid"),
                text(n, "fileid"),
                text(n, "filename"),   // actual filename e.g. "Catan_Rules.pdf"
                text(n, "title"),      // human title e.g. "Catan Rulebook 5th edition"
                text(n, "size"),       // file size in bytes as string
                text(n, "language"),
                text(n, "languageid"),
                text(n, "href"),       // /filepage/{filepageid}/slug
                text(n, "postdate")
        );
    }

    private boolean isRulebookCandidate(BggFileEntry e) {
        if (!isPdfFilename(e.filename())) return false; // skip non-PDF files

        String title = e.title() != null ? e.title().toLowerCase() : "";
        String filename = e.filename() != null ? e.filename().toLowerCase() : "";

        // Positive signals
        boolean titleMatch = title.contains("rule") || title.contains("manual")
                || title.contains("quickstart") || title.contains("quick start")
                || title.contains("quick-start") || title.contains("learn to play")
                || title.contains("how to play") || title.contains("rulebook");

        boolean filenameMatch = filename.contains("rule") || filename.contains("manual")
                || filename.contains("quickstart");

        // Negative signals — player aids, variants, expansions, etc.
        boolean noise = title.contains("variant") || title.contains("player aid")
                || title.contains("summary") || title.contains("expansion")
                || title.contains("errata") || title.contains("faq")
                || title.contains("scenario");

        return (titleMatch || filenameMatch) && !noise;
    }

    private boolean isPdfFilename(String filename) {
        return filename != null && filename.toLowerCase().endsWith(".pdf");
    }

    private String text(JsonNode n, String field) {
        JsonNode v = n.get(field);
        return (v != null && !v.isNull()) ? v.asText() : null;
    }

    // -------------------------------------------------------------------------
    // DTOs

    public record BggFileEntry(
            String filepageid,
            String fileid,
            String filename,    // actual file name e.g. "Catan_Rules_5th_Ed.pdf"
            String title,       // human-readable title from uploader
            String size,        // bytes as string
            String language,
            String languageid,
            String href,        // /filepage/{filepageid}/slug — NOT a direct download URL
            String postdate
    ) {}

    public record BggFilesProbeResult(
            long bggId,
            boolean reachable,
            String error,
            List<BggFileEntry> allFiles,
            List<BggFileEntry> rulebookCandidates,
            int totalPages,
            int totalItems,
            String rawJson
    ) {
        static BggFilesProbeResult error(long bggId, String msg) {
            return new BggFilesProbeResult(bggId, false, msg, List.of(), List.of(), 0, 0, null);
        }
    }
}
