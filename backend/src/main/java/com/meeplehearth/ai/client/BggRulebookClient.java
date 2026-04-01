package com.meeplehearth.ai.client;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import java.util.ArrayList;
import java.util.List;

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

    public BggRulebookClient() {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(TIMEOUT_MS);
        factory.setReadTimeout(TIMEOUT_MS);

        this.bggApiClient = RestClient.builder()
                .baseUrl("https://api.geekdo.com")
                .requestFactory(factory)
                .defaultHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) MeepleHearth/1.0")
                .defaultHeader("Accept", "application/json")
                .build();

        // For resolving filepage download links
        this.bggWebClient = RestClient.builder()
                .baseUrl("https://boardgamegeek.com")
                .requestFactory(factory)
                .defaultHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) MeepleHearth/1.0")
                .defaultHeader("Accept", "text/html,application/xhtml+xml,application/pdf")
                .build();
    }

    // -------------------------------------------------------------------------
    // Probe — returns full picture for verification

    public BggFilesProbeResult probe(long bggId) {
        return fetchPage(bggId, 1, null);
    }

    /**
     * Probe with language filter.
     * languageId: "2184"=English, "2181"=Chinese, null=all languages
     */
    public BggFilesProbeResult probe(long bggId, String languageId) {
        return fetchPage(bggId, 1, languageId);
    }

    // -------------------------------------------------------------------------
    // Resolve — find the best English rulebook PDF and return its download URL

    /**
     * Searches up to maxPages pages (10 files each) for an English PDF that
     * looks like a rulebook. Returns the download URL if found, else empty.
     *
     * Used by the background ingestion job once the probe verifies the API works.
     */
    public java.util.Optional<String> resolveRulebookUrl(long bggId, int maxPages) {
        for (int page = 1; page <= maxPages; page++) {
            BggFilesProbeResult result = fetchPage(bggId, page, ENGLISH_LANGUAGE_ID);
            if (!result.reachable()) break;

            for (BggFileEntry entry : result.rulebookCandidates()) {
                String url = tryResolveDownloadUrl(entry);
                if (url != null) return java.util.Optional.of(url);
            }

            // No more pages
            if (result.totalPages() > 0 && page >= result.totalPages()) break;
        }
        return java.util.Optional.empty();
    }

    // -------------------------------------------------------------------------

    private BggFilesProbeResult fetchPage(long bggId, int page, String languageId) {
        String rawJson = null;
        try {
            String uri = languageId != null
                    ? "/api/files?objecttype=thing&objectid={id}&sort=recent&start=0&pageid={page}&languageid={lang}"
                    : "/api/files?objecttype=thing&objectid={id}&sort=recent&start=0&pageid={page}";

            rawJson = languageId != null
                    ? bggApiClient.get().uri(uri, bggId, page, languageId).retrieve().body(String.class)
                    : bggApiClient.get().uri(uri, bggId, page).retrieve().body(String.class);

        } catch (RestClientException e) {
            log.warn("BGG files API failed for bggId={}: {}", bggId, e.getMessage());
            return BggFilesProbeResult.error(bggId, "HTTP error: " + e.getMessage());
        }

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
     * Strategy: GET boardgamegeek.com{href} — BGG may redirect to the actual
     * file at cf.geekdo-images.com or serve HTML. We check Content-Type or
     * follow Location header.
     *
     * Returns the resolved URL if it looks like a direct PDF link, else null.
     */
    public String tryResolveDownloadUrl(BggFileEntry entry) {
        if (entry.href() == null) return null;
        // Only attempt PDFs — skip images, docs, etc.
        if (!isPdfFilename(entry.filename())) return null;

        try {
            // BGG filepage redirect sometimes goes directly to the CDN PDF.
            // We fetch the response and inspect the final URL / Content-Type.
            String response = bggWebClient.get()
                    .uri(entry.href())
                    .retrieve()
                    .body(String.class);

            if (response == null) return null;

            // If BGG returned HTML (the filepage), look for the download link
            if (response.contains("<html") || response.contains("<!DOCTYPE")) {
                return extractDownloadLinkFromHtml(response, entry.href());
            }

            // If it's not HTML, assume it streamed the file — but we can't get URL this way
            // Return the href as-is for now; the ingestion job will stream it
            return "https://boardgamegeek.com" + entry.href();

        } catch (RestClientException e) {
            log.debug("Could not resolve download URL for fileid={}: {}", entry.fileid(), e.getMessage());
            return null;
        }
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
