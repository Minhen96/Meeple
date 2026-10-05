package com.meeplehearth.ai.client;

import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;
import io.netty.handler.ssl.SslContext;
import io.netty.handler.ssl.SslContextBuilder;
import io.netty.resolver.AbstractAddressResolver;
import io.netty.resolver.AddressResolver;
import io.netty.resolver.AddressResolverGroup;
import io.netty.util.concurrent.EventExecutor;
import io.netty.util.concurrent.Promise;
import okhttp3.mockwebserver.MockResponse;
import okhttp3.mockwebserver.MockWebServer;
import okhttp3.tls.HandshakeCertificates;
import okhttp3.tls.HeldCertificate;
import okio.Buffer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import reactor.netty.http.client.HttpClient;
import reactor.netty.resources.ConnectionProvider;

import java.io.IOException;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.time.Duration;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * The redirect / status / content-type / size / magic-byte handling of {@link SafePdfDownloader}
 * over real HTTPS. URLs keep their allowlisted hosts (validated with a stubbed public DNS answer);
 * only the transport is redirected: the downloader's HTTP client is replaced by one that resolves
 * every host to a local TLS MockWebServer whose certificate is issued for those hosts.
 */
class SafePdfDownloaderHttpTest {

    private static final byte[] PDF = "%PDF-1.7\n1 0 obj\n<<>>\nendobj\n%%EOF".getBytes();

    private MockWebServer server;
    private SafePdfDownloader downloader;

    /** Resolves every host to the mock server (port included), like a hosts-file override. */
    private static final class LoopbackResolverGroup extends AddressResolverGroup<InetSocketAddress> {
        private final int port;

        LoopbackResolverGroup(int port) {
            this.port = port;
        }

        @Override
        protected AddressResolver<InetSocketAddress> newResolver(EventExecutor executor) {
            return new AbstractAddressResolver<>(executor) {
                @Override
                protected boolean doIsResolved(InetSocketAddress address) {
                    return !address.isUnresolved();
                }

                @Override
                protected void doResolve(InetSocketAddress unresolved, Promise<InetSocketAddress> promise) {
                    promise.setSuccess(new InetSocketAddress(InetAddress.getLoopbackAddress(), port));
                }

                @Override
                protected void doResolveAll(InetSocketAddress unresolved, Promise<List<InetSocketAddress>> promise) {
                    promise.setSuccess(List.of(new InetSocketAddress(InetAddress.getLoopbackAddress(), port)));
                }
            };
        }
    }

    @BeforeEach
    void setUp() throws Exception {
        HeldCertificate root = new HeldCertificate.Builder().certificateAuthority(0).build();
        HeldCertificate serverCert = new HeldCertificate.Builder()
                .addSubjectAlternativeName("cdn.1j1ju.com")
                .addSubjectAlternativeName("boardgamegeek.com")
                .signedBy(root)
                .build();
        HandshakeCertificates serverCerts = new HandshakeCertificates.Builder()
                .heldCertificate(serverCert, root.certificate())
                .build();
        server = new MockWebServer();
        server.useHttps(serverCerts.sslSocketFactory(), false);
        server.start();

        RulebookUrlValidator validator = new RulebookUrlValidator(host -> new InetAddress[]{
                InetAddress.getByName("104.18.10.20")});
        downloader = new SafePdfDownloader(validator, CircuitBreakerRegistry.ofDefaults());
        SslContext trustRoot = SslContextBuilder.forClient().trustManager(root.certificate()).build();
        HttpClient testTransport = HttpClient.create(ConnectionProvider.newConnection())
                .resolver(new LoopbackResolverGroup(server.getPort()))
                .followRedirect(false)
                .responseTimeout(Duration.ofSeconds(5))
                .secure(spec -> spec.sslContext(trustRoot));
        ReflectionTestUtils.setField(downloader, "httpClient", testTransport);
    }

    @AfterEach
    void tearDown() throws IOException {
        downloader.shutdown();
        server.shutdown();
    }

    private static MockResponse pdf() {
        return new MockResponse().setHeader("Content-Type", "application/pdf").setBody(new Buffer().write(PDF));
    }

    @Test
    void downloadsPdfOverHttps() throws Exception {
        server.enqueue(pdf());

        assertThat(downloader.download("https://cdn.1j1ju.com/medias/catan.pdf")).isEqualTo(PDF);
        var request = server.takeRequest();
        assertThat(request.getPath()).isEqualTo("/medias/catan.pdf");
        assertThat(request.getHeader("Host")).isEqualTo("cdn.1j1ju.com");
    }

    @Test
    void followsValidatedRedirects() throws Exception {
        server.enqueue(new MockResponse().setResponseCode(302).setHeader("Location", "/files/real.pdf"));
        server.enqueue(new MockResponse().setResponseCode(301)
                .setHeader("Location", "https://boardgamegeek.com/dl/real.pdf"));
        server.enqueue(new MockResponse().setHeader("Content-Type", "binary/octet-stream").setBody(new Buffer().write(PDF)));

        assertThat(downloader.download("https://cdn.1j1ju.com/start.pdf")).isEqualTo(PDF);
        assertThat(server.takeRequest().getPath()).isEqualTo("/start.pdf");
        assertThat(server.takeRequest().getPath()).isEqualTo("/files/real.pdf");
        assertThat(server.takeRequest().getHeader("Host")).isEqualTo("boardgamegeek.com");
    }

    @Test
    void redirectToNonAllowlistedHostIsRejected() {
        server.enqueue(new MockResponse().setResponseCode(302).setHeader("Location", "https://evil.example/x.pdf"));

        assertThatThrownBy(() -> downloader.download("https://cdn.1j1ju.com/a.pdf"))
                .isInstanceOf(RulebookUrlValidator.UnsafeUrlException.class);
        assertThat(server.getRequestCount()).isEqualTo(1);
    }

    @Test
    void redirectWithoutLocationOrTooManyRedirectsFail() {
        server.enqueue(new MockResponse().setResponseCode(302));
        assertThatThrownBy(() -> downloader.download("https://cdn.1j1ju.com/a.pdf"))
                .isInstanceOf(SafePdfDownloader.PdfDownloadException.class)
                .hasMessage("Redirect without Location header");

        for (int i = 0; i <= SafePdfDownloader.MAX_REDIRECTS; i++) {
            server.enqueue(new MockResponse().setResponseCode(307).setHeader("Location", "/loop" + i + ".pdf"));
        }
        assertThatThrownBy(() -> downloader.download("https://cdn.1j1ju.com/a.pdf"))
                .isInstanceOf(SafePdfDownloader.PdfDownloadException.class)
                .hasMessage("Too many redirects");
    }

    @Test
    void httpStatusesAreClassified() {
        server.enqueue(new MockResponse().setResponseCode(404));
        assertThatThrownBy(() -> downloader.download("https://cdn.1j1ju.com/a.pdf"))
                .isExactlyInstanceOf(SafePdfDownloader.PdfDownloadException.class)
                .hasMessage("Unexpected HTTP status 404");

        server.enqueue(new MockResponse().setResponseCode(503));
        assertThatThrownBy(() -> downloader.download("https://cdn.1j1ju.com/a.pdf"))
                .isInstanceOf(SafePdfDownloader.TransientDownloadException.class);

        server.enqueue(new MockResponse().setResponseCode(429));
        assertThatThrownBy(() -> downloader.download("https://cdn.1j1ju.com/a.pdf"))
                .isInstanceOf(SafePdfDownloader.TransientDownloadException.class)
                .hasMessage("Unexpected HTTP status 429");
    }

    @Test
    void wrongContentIsRejected() {
        server.enqueue(new MockResponse().setHeader("Content-Type", "text/html").setBody("<html></html>"));
        assertThatThrownBy(() -> downloader.download("https://cdn.1j1ju.com/a.pdf"))
                .hasMessage("Unexpected Content-Type: text/html");

        server.enqueue(new MockResponse().setHeader("Content-Type", "application/octet-stream").setBody("not a pdf"));
        assertThatThrownBy(() -> downloader.download("https://cdn.1j1ju.com/a.pdf"))
                .hasMessage("Response body is not a PDF");
    }

    @Test
    void declaredOversizeBodyIsRejectedBeforeReading() {
        // Body first: setBody() would otherwise overwrite the declared length
        server.enqueue(new MockResponse().setBody(new Buffer().write(PDF))
                .setHeader("Content-Type", "application/pdf")
                .setHeader("Content-Length", String.valueOf(SafePdfDownloader.MAX_BYTES + 1L)));

        assertThatThrownBy(() -> downloader.download("https://cdn.1j1ju.com/huge.pdf"))
                .isInstanceOf(SafePdfDownloader.PdfDownloadException.class)
                .hasMessageContaining("exceeds");
    }

    @Test
    void connectionFailuresAreTransient() throws IOException {
        server.shutdown();

        assertThatThrownBy(() -> downloader.download("https://cdn.1j1ju.com/a.pdf"))
                .isInstanceOf(SafePdfDownloader.TransientDownloadException.class)
                .hasMessageStartingWith("Download failed");
    }

    @Test
    void invalidInitialUrlIsRejectedWithoutConnecting() {
        assertThatThrownBy(() -> downloader.download("http://cdn.1j1ju.com/a.pdf"))
                .isInstanceOf(RulebookUrlValidator.UnsafeUrlException.class);
        assertThat(server.getRequestCount()).isZero();
    }
}
