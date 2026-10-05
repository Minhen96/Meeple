package com.meeplehearth.ai.client;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import org.jsoup.HttpStatusException;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.util.Optional;

/**
 * Client for en.1jour-1jeu.com — backup auto-fetch source.
 *
 * Scrapes the HTML search results page for cdn.1j1ju.com PDF links.
 * Same CDN as rule-book.org but wider game coverage.
 *
 * URL: GET https://en.1jour-1jeu.com/rules/search?q={name}
 *
 * Guarded by the "onj" circuit breaker. Returned links are only candidates:
 * they are re-validated by {@link SafePdfDownloader} before download.
 */
@Component
public class OnjRulebookClient {

    private static final Logger log = LoggerFactory.getLogger(OnjRulebookClient.class);
    private static final String SEARCH_URL = "https://en.1jour-1jeu.com/rules/search";
    private static final String CDN_HOST = "cdn.1j1ju.com";
    private static final int MAX_BODY_BYTES = 2 * 1024 * 1024;

    /**
     * Find the first English rulebook PDF URL for the given game name.
     * Returns empty if no CDN PDF link is found; request failures are recorded by
     * the circuit breaker and mapped to empty by the fallback.
     */
    @CircuitBreaker(name = "onj", fallbackMethod = "findPdfUrlFallback")
    public Optional<String> findPdfUrl(String gameName) {
        Document doc;
        try {
            doc = Jsoup.connect(SEARCH_URL)
                    .data("q", gameName)
                    .userAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) Meeple/1.0")
                    .timeout(15_000)
                    .maxBodySize(MAX_BODY_BYTES)
                    .get();
        } catch (HttpStatusException e) {
            if (e.getStatusCode() == 404) return Optional.empty();
            throw new UncheckedIOException("1jour-1jeu search failed", e);
        } catch (IOException e) {
            throw new UncheckedIOException("1jour-1jeu search failed", e);
        }

        return doc.select("a[href]").stream()
                .map(el -> el.attr("abs:href"))
                .filter(href -> href.startsWith("https://" + CDN_HOST + "/") && href.endsWith(".pdf"))
                .findFirst();
    }

    @SuppressWarnings("unused")
    private Optional<String> findPdfUrlFallback(String gameName, Throwable t) {
        log.warn("1jour-1jeu lookup unavailable: {}", t.getMessage());
        return Optional.empty();
    }
}
