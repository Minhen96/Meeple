package com.meeplehearth.ai.client;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.netty.channel.ChannelOption;
import io.netty.handler.codec.http.HttpHeaderNames;
import io.netty.handler.codec.http.HttpHeaders;
import jakarta.annotation.PreDestroy;
import org.springframework.stereotype.Component;
import reactor.core.Exceptions;
import reactor.core.publisher.Mono;
import reactor.netty.ByteBufFlux;
import reactor.netty.http.client.HttpClient;
import reactor.netty.http.client.HttpClientResponse;
import reactor.netty.resources.ConnectionProvider;
import reactor.netty.resources.LoopResources;

import java.io.ByteArrayOutputStream;
import java.net.URI;
import java.time.Duration;
import java.util.Locale;
import java.util.concurrent.TimeoutException;

/**
 * Downloads rulebook PDFs from third-party hosts with SSRF and size protection.
 *
 *   - every URL (including each redirect hop) goes through {@link RulebookUrlValidator}
 *   - every connection resolves its host through {@link PublicAddressResolverGroup}, which
 *     rejects non-public addresses at connect time, so the validated address is the one used
 *     (no DNS-rebinding window between validation and connection)
 *   - redirects are followed manually, at most {@value #MAX_REDIRECTS} hops
 *   - body is streamed with a hard cap of {@value #MAX_BYTES} bytes
 *   - Content-Type must be a PDF type (or a generic binary type) and the body must
 *     start with the %PDF magic bytes
 *
 * Guarded by the "rulebookDownload" circuit breaker.
 */
@Component
public class SafePdfDownloader {

    static final int MAX_REDIRECTS = 3;
    static final int MAX_BYTES = 50 * 1024 * 1024; // 50 MB
    private static final byte[] PDF_MAGIC = {0x25, 0x50, 0x44, 0x46}; // %PDF
    private static final String USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Meeple/1.0";
    private static final int CONNECT_TIMEOUT_MS = 15_000;
    /** Longest silence allowed while waiting for / reading a response. */
    private static final Duration READ_TIMEOUT = Duration.ofSeconds(60);
    /** Upper bound for one hop, body included. */
    private static final Duration HOP_TIMEOUT = Duration.ofSeconds(180);

    private final RulebookUrlValidator urlValidator;
    private final LoopResources loopResources;
    private final HttpClient httpClient;

    public SafePdfDownloader(RulebookUrlValidator urlValidator) {
        this.urlValidator = urlValidator;
        // Own event loop: the pinned resolver blocks on DNS and must not stall shared loops
        this.loopResources = LoopResources.create("rulebook-download", 2, true);
        this.httpClient = HttpClient.create(ConnectionProvider.newConnection())
                .runOn(loopResources)
                .resolver(new PublicAddressResolverGroup(urlValidator.hostResolver()))
                .followRedirect(false)
                .option(ChannelOption.CONNECT_TIMEOUT_MILLIS, CONNECT_TIMEOUT_MS)
                .responseTimeout(READ_TIMEOUT)
                .headers(h -> h
                        .set(HttpHeaderNames.USER_AGENT, USER_AGENT)
                        .set(HttpHeaderNames.ACCEPT, "application/pdf,application/octet-stream;q=0.9"));
    }

    @PreDestroy
    void shutdown() {
        loopResources.disposeLater().block(Duration.ofSeconds(5));
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
            Hop result = fetch(current);

            if (result.isRedirect()) {
                if (result.location() == null || result.location().isBlank()) {
                    throw new PdfDownloadException("Redirect without Location header");
                }
                if (hop == MAX_REDIRECTS) {
                    throw new PdfDownloadException("Too many redirects");
                }
                URI next = current.resolve(result.location().strip());
                current = urlValidator.validate(next.toString());
                continue;
            }

            if (!hasPdfMagic(result.body())) {
                throw new PdfDownloadException("Response body is not a PDF");
            }
            return result.body();
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

    /** One HTTP exchange: either a redirect (status + Location) or a capped 2xx body. */
    private record Hop(int status, String location, byte[] body) {
        boolean isRedirect() {
            return status >= 300 && status < 400;
        }
    }

    private Hop fetch(URI uri) {
        Hop hop;
        try {
            hop = httpClient.get()
                    .uri(uri)
                    .response(SafePdfDownloader::handleResponse)
                    .next()
                    .timeout(HOP_TIMEOUT)
                    .block();
        } catch (RuntimeException e) {
            throw translate(e);
        }
        if (hop == null) {
            throw new PdfDownloadException("Empty response");
        }
        return hop;
    }

    private static Mono<Hop> handleResponse(HttpClientResponse response, ByteBufFlux content) {
        int status = response.status().code();
        HttpHeaders headers = response.responseHeaders();

        // Unconsumed bodies are released when the (unpooled) connection closes
        if (status >= 300 && status < 400) {
            return Mono.just(new Hop(status, headers.get(HttpHeaderNames.LOCATION), null));
        }
        if (status < 200 || status >= 300) {
            return Mono.error(new PdfDownloadException("Unexpected HTTP status " + status));
        }

        String contentType = headers.get(HttpHeaderNames.CONTENT_TYPE, "").toLowerCase(Locale.ROOT);
        if (!isAcceptableContentType(contentType)) {
            return Mono.error(new PdfDownloadException("Unexpected Content-Type: " + contentType));
        }

        String lengthHeader = headers.get(HttpHeaderNames.CONTENT_LENGTH);
        if (lengthHeader != null) {
            try {
                if (Long.parseLong(lengthHeader.strip()) > MAX_BYTES) {
                    return Mono.error(new PdfDownloadException("PDF exceeds " + MAX_BYTES + " bytes"));
                }
            } catch (NumberFormatException ignored) {
                // Fall through to the streaming cap below
            }
        }

        return content.asByteArray()
                .reduceWith(() -> new ByteArrayOutputStream(64 * 1024), (out, chunk) -> {
                    if ((long) out.size() + chunk.length > MAX_BYTES) {
                        throw new PdfDownloadException("PDF exceeds " + MAX_BYTES + " bytes");
                    }
                    out.write(chunk, 0, chunk.length);
                    return out;
                })
                .map(out -> new Hop(status, null, out.toByteArray()));
    }

    static boolean isAcceptableContentType(String contentType) {
        String ct = contentType == null ? "" : contentType.toLowerCase(Locale.ROOT);
        boolean pdfType = ct.startsWith("application/pdf") || ct.startsWith("application/x-pdf");
        boolean binaryType = ct.isEmpty()
                || ct.startsWith("application/octet-stream")
                || ct.startsWith("binary/octet-stream");
        return pdfType || binaryType;
    }

    /** Surfaces our own exceptions from anywhere in the cause chain; wraps everything else. */
    static RuntimeException translate(Throwable error) {
        Throwable unwrapped = Exceptions.unwrap(error);
        for (Throwable t = unwrapped; t != null; t = t.getCause()) {
            if (t instanceof RulebookUrlValidator.UnsafeUrlException unsafe) return unsafe;
            if (t instanceof PdfDownloadException pde) return pde;
            if (t.getCause() == t) break;
        }
        if (unwrapped instanceof TimeoutException) {
            return new PdfDownloadException("Download timed out", unwrapped);
        }
        return new PdfDownloadException("Download failed: " + unwrapped.getMessage(), unwrapped);
    }

    static boolean hasPdfMagic(byte[] bytes) {
        if (bytes == null || bytes.length < PDF_MAGIC.length) return false;
        for (int i = 0; i < PDF_MAGIC.length; i++) {
            if (bytes[i] != PDF_MAGIC[i]) return false;
        }
        return true;
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
