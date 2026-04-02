package com.meeplehearth.ai.client;

import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.springframework.stereotype.Component;

import java.util.Optional;

/**
 * Client for en.1jour-1jeu.com — backup auto-fetch source.
 *
 * Scrapes the HTML search results page for cdn.1j1ju.com PDF links.
 * Same CDN as rule-book.org but wider game coverage.
 *
 * URL: GET https://en.1jour-1jeu.com/rules/search?q={name}
 */
@Component
public class OnjRulebookClient {

    private static final String SEARCH_URL = "https://en.1jour-1jeu.com/rules/search";
    private static final String CDN_HOST = "cdn.1j1ju.com";

    /**
     * Find the first English rulebook PDF URL for the given game name.
     * Returns empty if no CDN PDF link is found on the page or the request fails.
     */
    public Optional<String> findPdfUrl(String gameName) {
        try {
            Document doc = Jsoup.connect(SEARCH_URL)
                    .data("q", gameName)
                    .userAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) Meeple/1.0")
                    .timeout(15_000)
                    .get();

            return doc.select("a[href]").stream()
                    .map(el -> el.attr("abs:href"))
                    .filter(href -> href.contains(CDN_HOST) && href.endsWith(".pdf"))
                    .findFirst();

        } catch (Exception e) {
            return Optional.empty();
        }
    }
}
