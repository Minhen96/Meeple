package com.meeplehearth.support.ai;

import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.PDPage;
import org.apache.pdfbox.pdmodel.PDPageContentStream;
import org.apache.pdfbox.pdmodel.font.PDType1Font;
import org.apache.pdfbox.pdmodel.font.Standard14Fonts;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.util.ArrayList;
import java.util.List;

/** Builds small real PDFs in memory for upload / ingestion tests. */
public final class TestPdfs {

    private static final int WORDS_PER_LINE = 12;
    private static final int LINES_PER_PAGE = 45;

    private TestPdfs() {
    }

    /** A PDF whose extracted text is the given words (wrapped over lines and pages as needed). */
    public static byte[] withText(String text) {
        String[] words = text.trim().isEmpty() ? new String[0] : text.trim().split("\\s+");
        List<String> lines = new ArrayList<>();
        for (int i = 0; i < words.length; i += WORDS_PER_LINE) {
            lines.add(String.join(" ", java.util.Arrays.copyOfRange(words, i, Math.min(words.length, i + WORDS_PER_LINE))));
        }
        try (PDDocument doc = new PDDocument(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            PDType1Font font = new PDType1Font(Standard14Fonts.FontName.HELVETICA);
            int index = 0;
            do {
                PDPage page = new PDPage();
                doc.addPage(page);
                try (PDPageContentStream cs = new PDPageContentStream(doc, page)) {
                    if (index < lines.size()) {
                        cs.beginText();
                        cs.setFont(font, 9);
                        cs.setLeading(14);
                        cs.newLineAtOffset(40, 740);
                        for (int n = 0; n < LINES_PER_PAGE && index < lines.size(); n++, index++) {
                            cs.showText(lines.get(index));
                            cs.newLine();
                        }
                        cs.endText();
                    }
                }
            } while (index < lines.size());
            doc.save(out);
            return out.toByteArray();
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    /** A valid PDF with no extractable text. */
    public static byte[] blank() {
        return withText("");
    }

    /** {@code count} distinct words: w0 w1 w2 ... */
    public static String words(String prefix, int count) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < count; i++) {
            if (i > 0) sb.append(' ');
            sb.append(prefix).append(i);
        }
        return sb.toString();
    }
}
