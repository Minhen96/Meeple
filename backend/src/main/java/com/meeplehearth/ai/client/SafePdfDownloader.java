package com.meeplehearth.ai.client;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Locale;
import java.util.Optional;

/**
 * Downloads rulebook PDFs from third-party hosts with SSRF and size protection.
 *
 *   - every URL (including each redirect hop) goes through {@link RulebookUrlValidator}
 *   - redirects are followed manually, at most {@value #MAX_REDIRECTS} hops
 *   - body is streamed with a hard cap of {@value #MAX_BYTES} bytes
 *   - Content-Type must be a PDF type (or a generic binary type) and the body must
 *     start with the %PDF magic bytes
 *
 * Guarded by the "rulebookDownload" circuit breaker.
 */
@Component
public class SafePdfDownloader {

    private static final Logger log = LoggerFactory.getLogger(SafePdfDownloader.class);

    static final int MAX_REDIRECTS = 3;
    static final int MAX_BYTES = 50 * 1024 * 1024; // 50 MB
    private static final byte[] PDF_MAGIC = {0x25, 0x50, 0x44, 0x46}; // %PDF
    private static final String USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Meeple/1.0";

    private final RulebookUrlValidator urlValidator;
    private final HttpClient httpClient;

    public SafePdfDownloader(RulebookUrlValidator urlValidator) {
        this.urlValidator = urlValidator;
        this.httpClient = HttpClient.newBuilder()
                .followRedirects(HttpClient.Redirect.NEVER)
                .connectTimeout(Duration.ofSeconds(15))
                .build();
    }

    /**
     * Downloads a PDF and returns its bytes.
     *
     * @throws RulebookUrlValidator.UnsafeUrlException if any hop fails validation
     * @throws PdfDownloadException on HTTP / size / content errors
     */
    @CircuitBreaker(name = "rulebookDownload", fallbackMethod = "downloadFallback")
    public byte[] download(String url) {
        URI current = urlValidator.validate(url);

        for (int hop = 0; hop <= MAX_REDIRECTS; hop++) {
            HttpRequest request = HttpRequest.newBuilder(current)
                    .timeout(Duration.ofSeconds(60))
                    .header("User-Agent", USER_AGENT)
                    .header("Accept", "application/pdf,application/octet-stream;q=0.9")
                    .GET()
                    .build();

            HttpResponse<InputStream> response;
            try {
                response = httpClient.send(request, HttpResponse.BodyHandlers.ofInputStream());
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new PdfDownloadException("Download interrupted", e);
            } catch (IOException e) {
                throw new PdfDownloadException("Download failed: " + e.getMessage(), e);
            }

            int status = response.statusCode();
            if (status >= 300 && status < 400) {
                closeQuietly(response.body());
                String location = response.headers().firstValue("Location")
                        .orElseThrow(() -> new PdfDownloadException("Redirect without Location header"));
                if (hop == MAX_REDIRECTS) {
                    throw new PdfDownloadException("Too many redirects");
                }
                URI next = current.resolve(location.strip());
                current = urlValidator.validate(next.toString());
                continue;
            }

            if (status < 200 || status >= 300) {
                closeQuietly(response.body());
                throw new PdfDownloadException("Unexpected HTTP status " + status);
            }

            return readPdfBody(response);
        }
        throw new PdfDownloadException("Too many redirects");
    }

    @SuppressWarnings("unused")
    private byte[] downloadFallback(String url, Throwable t) {
        if (t instanceof RulebookUrlValidator.UnsafeUrlException unsafe) throw unsafe;
        if (t instanceof PdfDownloadException pde) throw pde;
        throw new PdfDownloadException("Rulebook download unavailable: " + t.getMessage(), t);
    }

    // -------------------------------------------------------------------------

    private byte[] readPdfBody(HttpResponse<InputStream> response) {
        String contentType = response.headers().firstValue("Content-Type").orElse("")
                .toLowerCase(Locale.ROOT);
        boolean pdfType = contentType.startsWith("application/pdf") || contentType.startsWith("application/x-pdf");
        boolean binaryType = contentType.isEmpty()
                || contentType.startsWith("application/octet-stream")
                || contentType.startsWith("binary/octet-stream");
        if (!pdfType && !binaryType) {
            closeQuietly(response.body());
            throw new PdfDownloadException("Unexpected Content-Type: " + contentType);
        }

        Optional<String> lengthHeader = response.headers().firstValue("Content-Length");
        if (lengthHeader.isPresent()) {
            try {
                if (Long.parseLong(lengthHeader.get().strip()) > MAX_BYTES) {
                    closeQuietly(response.body());
                    throw new PdfDownloadException("PDF exceeds " + MAX_BYTES + " bytes");
                }
            } catch (NumberFormatException ignored) {
                // Fall through to the streaming cap below
            }
        }

        byte[] bytes;
        try (InputStream in = response.body()) {
            bytes = readCapped(in, MAX_BYTES);
        } catch (IOException e) {
            throw new PdfDownloadException("Failed reading PDF body: " + e.getMessage(), e);
        }

        if (!hasPdfMagic(bytes)) {
            throw new PdfDownloadException("Response body is not a PDF");
        }
        return bytes;
    }

    static byte[] readCapped(InputStream in, int maxBytes) throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream(64 * 1024);
        byte[] buf = new byte[64 * 1024];
        long total = 0;
        int n;
        while ((n = in.read(buf)) != -1) {
            total += n;
            if (total > maxBytes) {
                throw new PdfDownloadException("PDF exceeds " + maxBytes + " bytes");
            }
            out.write(buf, 0, n);
        }
        return out.toByteArray();
    }

    static boolean hasPdfMagic(byte[] bytes) {
        if (bytes == null || bytes.length < PDF_MAGIC.length) return false;
        for (int i = 0; i < PDF_MAGIC.length; i++) {
            if (bytes[i] != PDF_MAGIC[i]) return false;
        }
        return true;
    }

    private static void closeQuietly(InputStream in) {
        if (in == null) return;
        try {
            in.close();
        } catch (IOException e) {
            log.debug("Failed to close response stream: {}", e.getMessage());
        }
    }

    /** Thrown when a PDF cannot be downloaded or is not acceptable. */
    public static class PdfDownloadException extends RuntimeException {
        public PdfDownloadException(String message) {
            super(message);
        }

        public PdfDownloadException(String message, Throwable cause) {
            super(message, cause);
        }
    }
}
