package com.meeplehearth.game.client;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * BGG API client using api.geekdo.com JSON API.
 *
 * BGG migrated xmlapi2 to require Bearer auth (401). The public JSON API at
 * api.geekdo.com/api/geekitems works without authentication and returns proper
 * https://cf.geekdo-images.com/... image URLs. Does not support batch lookups —
 * each game requires a separate request.
 */
@Component
public class BggApiClient {
    private static final Logger log = LoggerFactory.getLogger(BggApiClient.class);

    private static final int TIMEOUT_MS = 10000;
    /** Delay between calls inside a batch to avoid rate-limiting. */
    private static final long INTER_CALL_DELAY_MS = 150;

    private final RestClient restClient;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public BggApiClient() {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(TIMEOUT_MS);
        factory.setReadTimeout(TIMEOUT_MS);

        this.restClient = RestClient.builder()
                .baseUrl("https://api.geekdo.com")
                .requestFactory(factory)
                .defaultHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Meeple/1.0")
                .defaultHeader("Accept", "application/json")
                .build();
    }

    /**
     * Search BGG for games by name.
     * Note: BGG's search API is unavailable without auth; callers should fall back
     * to local DB search when this returns an empty list.
     */
    @CircuitBreaker(name = "bgg", fallbackMethod = "searchFallback")
    public List<BggSearchResult> search(String query) {
        // BGG search endpoints require auth — return empty to trigger local DB fallback.
        return List.of();
    }

    @SuppressWarnings("unused")
    private List<BggSearchResult> searchFallback(String query, Exception e) {
        throw new BggUnavailableException("BGG search unavailable: " + e.getMessage());
    }

    /**
     * Fetch details (primarily image URLs) for a list of BGG IDs.
     * Makes one HTTP call per ID to api.geekdo.com/api/geekitems with a short
     * inter-call delay. Per-game failures are swallowed so one bad ID does not
     * abort the whole batch.
     */
    @CircuitBreaker(name = "bgg", fallbackMethod = "getDetailsFallback")
    public List<BggGameDetail> getDetails(List<Long> bggIds) {
        if (bggIds == null || bggIds.isEmpty()) return List.of();
        List<BggGameDetail> results = new ArrayList<>();
        for (Long id : bggIds) {
            try {
                String json = restClient.get()
                        .uri("/api/geekitems?nosession=1&objecttype=thing&objectid={id}", id)
                        .retrieve()
                        .body(String.class);
                parseGeekItem(json).ifPresent(results::add);
                if (bggIds.size() > 1) {
                    Thread.sleep(INTER_CALL_DELAY_MS);
                }
            } catch (InterruptedException ie) {
                Thread.currentThread().interrupt();
                break;
            } catch (Exception e) {
                log.warn("BGG: failed to fetch game id={}: {}", id, e.getMessage());
            }
        }
        return results;
    }

    @SuppressWarnings("unused")
    private List<BggGameDetail> getDetailsFallback(List<Long> bggIds, Exception e) {
        throw new BggUnavailableException("BGG details unavailable: " + e.getMessage());
    }

    @CircuitBreaker(name = "bgg", fallbackMethod = "getDetailFallback")
    public Optional<BggGameDetail> getDetail(Long bggId) {
        return getDetails(List.of(bggId)).stream().findFirst();
    }

    @SuppressWarnings("unused")
    private Optional<BggGameDetail> getDetailFallback(Long bggId, Exception e) {
        throw new BggUnavailableException("BGG detail unavailable: " + e.getMessage());
    }

    // -------------------------------------------------------------------------
    // JSON parsing
    // -------------------------------------------------------------------------

    private Optional<BggGameDetail> parseGeekItem(String json) {
        if (json == null) return Optional.empty();
        try {
            JsonNode root = objectMapper.readTree(json);
            JsonNode item = root.path("item");
            if (item.isMissingNode() || item.isNull()) return Optional.empty();

            String idStr = item.path("objectid").asText(null);
            if (idStr == null) return Optional.empty();
            long bggId = Long.parseLong(idStr);

            String name = item.path("name").asText(null);

            // Images — prefer previewthumb (300×320) for thumbnail, original for full
            JsonNode images = item.path("images");
            String thumbnail = images.path("previewthumb").asText(null);
            if (thumbnail == null) thumbnail = images.path("thumb").asText(null);
            if (thumbnail == null) thumbnail = images.path("square200").asText(null);

            String image = images.path("original").asText(null);
            if (image == null || image.isBlank()) image = item.path("imageurl").asText(null);
            if (image == null || image.isBlank()) image = thumbnail;

            // Basic metadata
            Integer year = intField(item, "yearpublished");
            Integer minP = intField(item, "minplayers");
            Integer maxP = intField(item, "maxplayers");
            Integer minT = intField(item, "minplaytime");
            Integer maxT = intField(item, "maxplaytime");

            // Strip HTML from description
            String description = item.path("description").asText(null);
            if (description != null) {
                description = description.replaceAll("<[^>]+>", "").strip();
                if (description.isBlank()) description = null;
            }

            // Links
            JsonNode links = item.path("links");
            String[] mechanics   = linkNames(links, "boardgamemechanic");
            String[] categories  = linkNames(links, "boardgamecategory");
            String[] subdomains  = linkNames(links, "boardgamesubdomain");
            String[] designers   = linkNames(links, "boardgamedesigner");
            String[] artists     = linkNames(links, "boardgameartist");
            String[] publishers  = linkNames(links, "boardgamepublisher");
            String[] honors      = linkNames(links, "boardgamehonor");
            // Store expansion BGG IDs (as strings) for in-app linking
            String[] expansions  = linkIds(links, "boardgameexpansion");

            String subtype = item.path("subtype").asText(null);
            String bggUrl  = item.path("href").asText(null);

            return Optional.of(new BggGameDetail(
                    bggId, name, thumbnail, image, description,
                    year, minP, maxP, minT, maxT, null, null,
                    mechanics, categories, subdomains, designers, artists, publishers,
                    honors, expansions, subtype, bggUrl
            ));
        } catch (Exception e) {
            log.warn("BGG: failed to parse geekitem response: {}", e.getMessage());
            return Optional.empty();
        }
    }

    private String[] linkNames(JsonNode links, String key) {
        JsonNode arr = links.path(key);
        if (arr.isMissingNode() || !arr.isArray() || arr.isEmpty()) return new String[0];
        List<String> names = new ArrayList<>();
        for (JsonNode n : arr) {
            String val = n.path("name").asText(null);
            if (val != null && !val.isBlank()) names.add(val);
        }
        return names.toArray(new String[0]);
    }

    private String[] linkIds(JsonNode links, String key) {
        JsonNode arr = links.path(key);
        if (arr.isMissingNode() || !arr.isArray() || arr.isEmpty()) return new String[0];
        List<String> ids = new ArrayList<>();
        for (JsonNode n : arr) {
            String id = n.path("objectid").asText(null);
            if (id != null && !id.isBlank()) ids.add(id);
        }
        return ids.toArray(new String[0]);
    }

    private Integer intField(JsonNode node, String field) {
        JsonNode n = node.path(field);
        if (n.isMissingNode() || n.isNull()) return null;
        String s = n.isTextual() ? n.asText() : null;
        if (s == null || s.isBlank()) return null;
        try { return Integer.parseInt(s); } catch (NumberFormatException e) { return null; }
    }

    // -------------------------------------------------------------------------
    // Inner types
    // -------------------------------------------------------------------------

    public record BggSearchResult(Long bggId, String title, Integer yearPublished) {}

    public record BggGameDetail(
            Long bggId,
            String title,
            String thumbnailUrl,
            String imageUrl,
            String description,
            Integer yearPublished,
            Integer minPlayers,
            Integer maxPlayers,
            Integer minPlaytime,
            Integer maxPlaytime,
            BigDecimal bggRating,
            BigDecimal complexityWeight,
            String[] mechanics,
            String[] categories,
            String[] subdomains,
            String[] designers,
            String[] artists,
            String[] publishers,
            String[] honors,
            String[] expansions,
            String subtype,
            String bggUrl
    ) {}

    public static class BggUnavailableException extends RuntimeException {
        public BggUnavailableException(String message) {
            super(message);
        }
    }
}
