package com.meeplehearth.ai.service;

import org.apache.pdfbox.Loader;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.text.PDFTextStripper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import java.util.Arrays;
import java.util.List;
import java.util.Map;

/**
 * Validates that a user-uploaded PDF is actually a rulebook for the given game,
 * using a quick LLM yes/no check on the first few pages of text.
 *
 * Fails open: if extraction or the LLM call itself throws, the PDF is accepted
 * (so a transient AI error never blocks a legitimate upload).
 */
@Service
public class PdfValidationService {

    private static final Logger log = LoggerFactory.getLogger(PdfValidationService.class);
    private static final int MAX_PAGES = 3;
    private static final int MAX_WORDS = 500;

    private final AiCompletionService completionService;

    public PdfValidationService(AiCompletionService completionService) {
        this.completionService = completionService;
    }

    /**
     * Returns true if the PDF appears to be a rulebook for {@code gameName}.
     * Always returns true on any error (fail open).
     */
    public boolean isRulebook(byte[] pdfBytes, String gameName) {
        try {
            String text = extractFirstWords(pdfBytes);
            if (text.isBlank()) return true; // can't validate — accept

            String prompt = """
                    Does the following document appear to be a rulebook, rules reference, or instructions for the board game "%s"?
                    Answer only YES or NO with no other text.

                    DOCUMENT EXCERPT:
                    %s
                    """.formatted(gameName, text);

            String response = completionService.complete(
                    List.of(Map.of("role", "user", "content", prompt)), 5, 0.0);

            boolean valid = response.strip().toUpperCase().startsWith("YES");
            if (!valid) {
                log.info("PDF rejected by LLM validation for game '{}': response='{}'", gameName, response.strip());
            }
            return valid;

        } catch (Exception e) {
            log.warn("PDF validation error for game '{}' (failing open): {}", gameName, e.getMessage());
            return true;
        }
    }

    private String extractFirstWords(byte[] pdfBytes) throws Exception {
        try (PDDocument doc = Loader.loadPDF(pdfBytes)) {
            PDFTextStripper stripper = new PDFTextStripper();
            stripper.setEndPage(Math.min(MAX_PAGES, doc.getNumberOfPages()));
            String text = stripper.getText(doc);
            String[] words = text.split("\\s+");
            return String.join(" ", Arrays.copyOf(words, Math.min(words.length, MAX_WORDS)));
        }
    }
}
