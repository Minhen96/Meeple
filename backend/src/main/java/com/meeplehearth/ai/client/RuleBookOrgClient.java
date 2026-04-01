package com.meeplehearth.ai.client;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.util.Optional;

/**
 * Client for api.rule-book.org — primary auto-fetch source.
 *
 * API: GET https://api.rule-book.org/games?search={name}&language=en
 * Response: { results: [{ id, name, link, language }] }
 * The `link` field is a direct cdn.1j1ju.com PDF URL — no further resolution needed.
 */
@Component
public class RuleBookOrgClient {

    private static final String BASE_URL = "https://api.rule-book.org";

    private final RestClient restClient;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public RuleBookOrgClient() {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(10_000);
        factory.setReadTimeout(15_000);

        this.restClient = RestClient.builder()
                .baseUrl(BASE_URL)
                .defaultHeader("User-Agent", "MeepleHearth/1.0")
                .requestFactory(factory)
                .build();
    }

    /**
     * Find the first English rulebook PDF URL for the given game name.
     * Returns empty if the API returns no results or the request fails.
     */
    public Optional<String> findPdfUrl(String gameName) {
        try {
            String response = restClient.get()
                    .uri(uri -> uri.path("/games")
                            .queryParam("search", gameName)
                            .queryParam("language", "en")
                            .build())
                    .retrieve()
                    .body(String.class);

            JsonNode results = objectMapper.readTree(response).path("results");
            if (results.isEmpty()) return Optional.empty();

            String link = results.get(0).path("link").asText("");
            return link.isBlank() ? Optional.empty() : Optional.of(link);

        } catch (Exception e) {
            return Optional.empty();
        }
    }
}
