package com.meeplehearth.game.client;

import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.util.StreamUtils;
import org.springframework.web.client.RestClient;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
import org.xml.sax.InputSource;
import org.xml.sax.helpers.DefaultHandler;

import javax.xml.XMLConstants;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import java.io.StringReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;

/**
 * BoardGameGeek XML API2 {@code /collection} client (FEATURES_COMPLETE section 3.2). The endpoint
 * requires a registered application token ({@code app.bgg.api-token}, sent as a Bearer token).
 *
 * <p>BGG answers 202 while it builds a collection; the client retries every
 * {@code app.bgg.collection-retry-delay-ms} (2s) up to {@code app.bgg.collection-max-retries} (10)
 * times. A 429 waits the same way. The call runs through the {@code bgg} circuit breaker: an
 * unknown username is a valid answer and counts as a success; transport errors, 5xx, a rejected
 * token and an exhausted 202 loop count as failures.
 */
@Component
public class BggCollectionClient {

    private static final Logger log = LoggerFactory.getLogger(BggCollectionClient.class);
    private static final int TIMEOUT_MS = 15_000;

    private final RestClient restClient;
    private final String apiToken;
    private final long retryDelayMs;
    private final int maxRetries;
    private final CircuitBreaker circuitBreaker;

    public BggCollectionClient(@Value("${app.bgg.xmlapi-base-url:https://boardgamegeek.com/xmlapi2}") String baseUrl,
                               @Value("${app.bgg.api-token:}") String apiToken,
                               @Value("${app.bgg.collection-retry-delay-ms:2000}") long retryDelayMs,
                               @Value("${app.bgg.collection-max-retries:10}") int maxRetries,
                               CircuitBreakerRegistry circuitBreakerRegistry) {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(TIMEOUT_MS);
        factory.setReadTimeout(TIMEOUT_MS);
        this.restClient = RestClient.builder()
                .baseUrl(baseUrl)
                .requestFactory(factory)
                .defaultHeader(HttpHeaders.USER_AGENT, "Meeple/1.0")
                .defaultHeader(HttpHeaders.ACCEPT, MediaType.APPLICATION_XML_VALUE + ", " + MediaType.TEXT_XML_VALUE)
                .build();
        this.apiToken = apiToken == null ? "" : apiToken.trim();
        this.retryDelayMs = Math.max(0, retryDelayMs);
        this.maxRetries = Math.max(0, maxRetries);
        this.circuitBreaker = circuitBreakerRegistry.circuitBreaker("bgg");
    }

    /** False when no BGG application token is configured: the collection endpoint cannot be called. */
    public boolean isConfigured() {
        return !apiToken.isEmpty();
    }

    /**
     * Board games (expansions excluded) the BGG user marked as owned.
     *
     * @throws BggUserNotFoundException BGG does not know the username
     * @throws BggApiClient.BggUnavailableException no token, breaker open, BGG down, or still queued after the retries
     */
    public List<CollectionItem> fetchOwnedCollection(String username) {
        if (!isConfigured()) {
            throw new BggApiClient.BggUnavailableException("BGG API token is not configured");
        }
        if (!circuitBreaker.tryAcquirePermission()) {
            throw new BggApiClient.BggUnavailableException("BGG circuit breaker is open");
        }
        long start = System.nanoTime();
        try {
            List<CollectionItem> items = fetchWithRetries(username);
            circuitBreaker.onSuccess(System.nanoTime() - start, TimeUnit.NANOSECONDS);
            return items;
        } catch (BggUserNotFoundException e) {
            circuitBreaker.onSuccess(System.nanoTime() - start, TimeUnit.NANOSECONDS);
            throw e;
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            circuitBreaker.releasePermission();
            throw new BggApiClient.BggUnavailableException("Interrupted while waiting for BGG");
        } catch (RuntimeException e) {
            circuitBreaker.onError(System.nanoTime() - start, TimeUnit.NANOSECONDS, e);
            if (e instanceof BggApiClient.BggUnavailableException unavailable) throw unavailable;
            log.warn("BGG collection request failed: {}", e.getMessage());
            throw new BggApiClient.BggUnavailableException("BGG collection request failed: " + e.getMessage());
        }
    }

    private List<CollectionItem> fetchWithRetries(String username) throws InterruptedException {
        for (int attempt = 0; ; attempt++) {
            Response response = restClient.get()
                    .uri(uri -> uri.path("/collection")
                            .queryParam("username", username)
                            .queryParam("own", 1)
                            .queryParam("excludesubtype", "boardgameexpansion")
                            .build())
                    .header(HttpHeaders.AUTHORIZATION, "Bearer " + apiToken)
                    .exchange((request, res) -> new Response(res.getStatusCode(),
                            StreamUtils.copyToString(res.getBody(), StandardCharsets.UTF_8)), true);

            int status = response.status().value();
            if (status == 202 || status == 429) {
                if (attempt >= maxRetries) {
                    throw new BggApiClient.BggUnavailableException(
                            "BGG still processing the collection after " + maxRetries + " retries");
                }
                TimeUnit.MILLISECONDS.sleep(retryDelayMs);
                continue;
            }
            if (status == 404) {
                throw new BggUserNotFoundException(username);
            }
            if (status == 401 || status == 403) {
                log.warn("BGG rejected the application token (HTTP {})", status);
                throw new BggApiClient.BggUnavailableException("BGG rejected the API token");
            }
            if (!response.status().is2xxSuccessful()) {
                throw new BggApiClient.BggUnavailableException("BGG answered HTTP " + status);
            }
            return parseCollection(response.body(), username);
        }
    }

    private record Response(HttpStatusCode status, String body) {
    }

    // -------------------------------------------------------------------------
    // XML parsing
    // -------------------------------------------------------------------------

    /**
     * Parses a {@code <items>} document. An {@code <errors>} document for an invalid username
     * means the user does not exist; any other unexpected document is a BGG failure.
     */
    static List<CollectionItem> parseCollection(String xml, String username) {
        if (xml == null || xml.isBlank()) {
            throw new BggApiClient.BggUnavailableException("Empty BGG collection response");
        }
        Element root = parse(xml).getDocumentElement();
        String rootName = root.getTagName();
        if ("errors".equals(rootName)) {
            String message = root.getTextContent() == null ? "" : root.getTextContent().toLowerCase();
            if (message.contains("invalid username")) {
                throw new BggUserNotFoundException(username);
            }
            throw new BggApiClient.BggUnavailableException("BGG returned an error document");
        }
        if ("message".equals(rootName)) {
            // Queued-request notice delivered with 200 instead of 202
            throw new BggApiClient.BggUnavailableException("BGG is still processing the collection");
        }
        if (!"items".equals(rootName)) {
            throw new BggApiClient.BggUnavailableException("Unexpected BGG response root <" + rootName + ">");
        }

        List<CollectionItem> items = new ArrayList<>();
        NodeList nodes = root.getElementsByTagName("item");
        for (int i = 0; i < nodes.getLength(); i++) {
            Element item = (Element) nodes.item(i);
            Long bggId = parseLong(item.getAttribute("objectid"));
            items.add(new CollectionItem(
                    bggId,
                    blankToNull(item.getAttribute("subtype")),
                    childText(item, "name"),
                    parseInt(childText(item, "yearpublished")),
                    normalizeUrl(childText(item, "thumbnail")),
                    normalizeUrl(childText(item, "image"))));
        }
        return items;
    }

    private static Document parse(String xml) {
        try {
            DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
            factory.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
            factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
            factory.setFeature("http://xml.org/sax/features/external-general-entities", false);
            factory.setFeature("http://xml.org/sax/features/external-parameter-entities", false);
            factory.setXIncludeAware(false);
            factory.setExpandEntityReferences(false);
            DocumentBuilder builder = factory.newDocumentBuilder();
            builder.setErrorHandler(new DefaultHandler()); // fatal errors throw; nothing printed to stderr
            return builder.parse(new InputSource(new StringReader(xml)));
        } catch (Exception e) {
            throw new BggApiClient.BggUnavailableException("BGG collection response is not valid XML");
        }
    }

    private static String childText(Element parent, String tag) {
        for (Node n = parent.getFirstChild(); n != null; n = n.getNextSibling()) {
            if (n instanceof Element e && tag.equals(e.getTagName())) {
                return blankToNull(e.getTextContent());
            }
        }
        return null;
    }

    private static String blankToNull(String s) {
        if (s == null) return null;
        String trimmed = s.strip();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private static Long parseLong(String s) {
        try {
            return s == null || s.isBlank() ? null : Long.parseLong(s.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private static Integer parseInt(String s) {
        try {
            return s == null ? null : Integer.parseInt(s.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    /** BGG image URLs may be protocol-relative ({@code //cf.geekdo-images.com/...}). */
    static String normalizeUrl(String url) {
        if (url == null) return null;
        return url.startsWith("//") ? "https:" + url : url;
    }

    /** One collection entry; {@code bggId} or {@code name} may be null for malformed items. */
    public record CollectionItem(Long bggId, String subtype, String name, Integer yearPublished,
                                 String thumbnailUrl, String imageUrl) {
    }

    /** BGG has no user with this name. */
    public static class BggUserNotFoundException extends RuntimeException {
        public BggUserNotFoundException(String username) {
            super("BGG user not found");
        }
    }
}
