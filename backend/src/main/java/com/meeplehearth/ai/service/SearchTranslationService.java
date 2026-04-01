package com.meeplehearth.ai.service;

import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;

/**
 * Translates non-English search queries (CJK, etc.) to English using the completion API.
 * If the query is already English, it is returned unchanged with translatedFrom = null.
 */
@Service
public class SearchTranslationService {

    private final AiCompletionService completionService;

    public SearchTranslationService(AiCompletionService completionService) {
        this.completionService = completionService;
    }

    public record TranslationResult(String query, String translatedFrom) {}

    /**
     * If the query contains CJK characters, translate to English and return the original.
     * Otherwise return the query unchanged with translatedFrom = null.
     */
    public TranslationResult translateIfNeeded(String query) {
        if (query == null || query.isBlank()) return new TranslationResult(query, null);
        if (!containsCjk(query)) return new TranslationResult(query, null);

        try {
            String translated = completionService.complete(List.of(
                    Map.of("role", "system",
                            "content", "You are a translation assistant for a board game search engine. "
                                    + "Translate the user's query into English. "
                                    + "Return ONLY the translated English text — no explanation, no punctuation, no quotes."),
                    Map.of("role", "user", "content", query)
            ), 50, 0.0);

            String cleaned = translated.strip();
            if (cleaned.isBlank()) return new TranslationResult(query, null);
            return new TranslationResult(cleaned, query);

        } catch (Exception e) {
            // Translation failure is non-fatal — fall back to original query
            return new TranslationResult(query, null);
        }
    }

    /** Returns true if the string contains any CJK (Chinese/Japanese/Korean) character. */
    private boolean containsCjk(String text) {
        for (char c : text.toCharArray()) {
            if ((c >= '\u4E00' && c <= '\u9FFF')    // CJK Unified Ideographs
                    || (c >= '\u3400' && c <= '\u4DBF') // CJK Extension A
                    || (c >= '\u3040' && c <= '\u309F') // Hiragana
                    || (c >= '\u30A0' && c <= '\u30FF') // Katakana
                    || (c >= '\uAC00' && c <= '\uD7AF')) { // Hangul
                return true;
            }
        }
        return false;
    }
}
