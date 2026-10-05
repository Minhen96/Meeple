package com.meeplehearth.ai.client;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestClient;

import java.io.IOException;
import java.net.HttpURLConnection;
import java.util.Optional;

/**
 * Client for api.rule-book.org — primary auto-fetch source.
 *
 * API: GET https://api.rule-book.org/games?search={name}&language=en
 * Response: { results: [{ id, name, link, language }] }
 * The `link` field is a direct cdn.1j1ju.com PDF URL — no further resolution needed.
 *
 * Guarded by the "rulebookOrg" circuit breaker. Returned links are only
 * candidates: they are re-validated by {@link SafePdfDownloader} before download.
 */
@Component
public class RuleBookOrgClient {

    private static final Logger log = LoggerFactory.getLogger(RuleBookOrgClient.class);
    private static final String BASE_URL = "https://api.rule-book.org";

    private final RestClient restClient;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public RuleBookOrgClient() {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory() {
            @Override
            protected void prepareConnection(HttpURLConnection connection, String httpMethod) throws IOException {
                super.prepareConnection(connection, httpMethod);
                connection.setInstanceFollowRedirects(false);
            }
        };
        factory.setConnectTimeout(10_000);
        factory.setReadTimeout(15_000);

        this.restClient = RestClient.builder()
                .baseUrl(BASE_URL)
                .defaultHeader("User-Agent", "Meeple/1.0")
                .requestFactory(factory)
                .build();
    }

    /**
     * Find the first English rulebook PDF URL for the given game name.
     * Returns empty if the API returns no results; HTTP / parse failures are
     * recorded by the circuit breaker and mapped to empty by the fallback.
     */
    @CircuitBreaker(name = "rulebookOrg", fallbackMethod = "findPdfUrlFallback")
    public Optional<String> findPdfUrl(String gameName) {
        String response;
        try {
            response = restClient.get()
                    .uri(uri -> uri.path("/games")
                            .queryParam("search", gameName)
                            .queryParam("language", "en")
                            .build())
                    .retrieve()
                    .body(String.class);
        } catch (HttpClientErrorException.NotFound e) {
            return Optional.empty();
        }

        if (response == null || response.isBlank()) return Optional.empty();

        JsonNode results;
        try {
            results = objectMapper.readTree(response).path("results");
        } catch (IOException e) {
            throw new IllegalStateException("Invalid JSON from rule-book.org", e);
        }
        if (!results.isArray() || results.isEmpty()) return Optional.empty();

        String link = results.get(0).path("link").asText("");
        return link.isBlank() ? Optional.empty() : Optional.of(link);
    }

    @SuppressWarnings("unused")
    private Optional<String> findPdfUrlFallback(String gameName, Throwable t) {
        log.warn("rule-book.org lookup unavailable: {}", t.getMessage());
        return Optional.empty();
    }
}
