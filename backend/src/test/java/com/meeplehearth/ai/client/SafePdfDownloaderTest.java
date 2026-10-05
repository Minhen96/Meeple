package com.meeplehearth.ai.client;

import io.netty.resolver.AddressResolver;
import io.netty.util.concurrent.Future;
import io.netty.util.concurrent.ImmediateEventExecutor;
import org.junit.jupiter.api.Test;

import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.UnknownHostException;
import java.util.List;
import java.util.concurrent.TimeoutException;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class SafePdfDownloaderTest {

    private static RulebookUrlValidator.HostResolver resolvingTo(String... ips) {
        return host -> {
            InetAddress[] out = new InetAddress[ips.length];
            for (int i = 0; i < ips.length; i++) {
                out[i] = InetAddress.getByName(ips[i]);
            }
            return out;
        };
    }

    private static Future<InetSocketAddress> resolveWith(RulebookUrlValidator.HostResolver hostResolver) {
        PublicAddressResolverGroup group = new PublicAddressResolverGroup(hostResolver);
        AddressResolver<InetSocketAddress> resolver = group.getResolver(ImmediateEventExecutor.INSTANCE);
        return resolver.resolve(InetSocketAddress.createUnresolved("cdn.1j1ju.com", 443)).awaitUninterruptibly();
    }

    @Test
    void connectTimeResolverReturnsPublicAddresses() {
        Future<InetSocketAddress> result = resolveWith(resolvingTo("104.18.10.20"));

        assertThat(result.isSuccess()).isTrue();
        assertThat(result.getNow().getAddress().getHostAddress()).isEqualTo("104.18.10.20");
        assertThat(result.getNow().getPort()).isEqualTo(443);
    }

    @Test
    void connectTimeResolverRejectsPrivateAddresses() {
        for (String ip : List.of("127.0.0.1", "10.1.2.3", "192.168.0.10", "169.254.169.254", "100.64.0.1",
                "::1", "fd00::1", "::ffff:10.0.0.1", "0.0.0.0")) {
            Future<InetSocketAddress> result = resolveWith(resolvingTo(ip));
            assertThat(result.isSuccess()).as(ip).isFalse();
            assertThat(result.cause()).as(ip).isInstanceOf(RulebookUrlValidator.UnsafeUrlException.class);
        }
    }

    @Test
    void connectTimeResolverRejectsWhenAnyAddressIsPrivate() {
        Future<List<InetSocketAddress>> all = new PublicAddressResolverGroup(resolvingTo("104.18.10.20", "10.0.0.1"))
                .getResolver(ImmediateEventExecutor.INSTANCE)
                .resolveAll(InetSocketAddress.createUnresolved("cdn.1j1ju.com", 443))
                .awaitUninterruptibly();

        assertThat(all.isSuccess()).isFalse();
        assertThat(all.cause()).isInstanceOf(RulebookUrlValidator.UnsafeUrlException.class);
    }

    @Test
    void connectTimeResolverFailsForUnresolvableHost() {
        Future<InetSocketAddress> result = resolveWith(host -> {
            throw new UnknownHostException(host);
        });

        assertThat(result.isSuccess()).isFalse();
        assertThat(result.cause()).isInstanceOf(UnknownHostException.class);
    }

    @Test
    void dnsRebindingAfterValidationIsBlockedAtConnectTime() {
        // First lookup (validation) answers with a public address, the next one (connection)
        // with loopback: the download must fail without ever connecting to loopback
        AtomicInteger lookups = new AtomicInteger();
        RulebookUrlValidator validator = new RulebookUrlValidator(host -> new InetAddress[]{
                InetAddress.getByName(lookups.getAndIncrement() == 0 ? "104.18.10.20" : "127.0.0.1")});
        SafePdfDownloader downloader = new SafePdfDownloader(validator);
        try {
            assertThatThrownBy(() -> downloader.download("https://cdn.1j1ju.com/rules/game.pdf"))
                    .isInstanceOf(RulebookUrlValidator.UnsafeUrlException.class);
            assertThat(lookups.get()).isGreaterThanOrEqualTo(2);
        } finally {
            downloader.shutdown();
        }
    }

    @Test
    void contentTypeAndMagicChecks() {
        assertThat(SafePdfDownloader.isAcceptableContentType("application/pdf; charset=binary")).isTrue();
        assertThat(SafePdfDownloader.isAcceptableContentType("")).isTrue();
        assertThat(SafePdfDownloader.isAcceptableContentType("binary/octet-stream")).isTrue();
        assertThat(SafePdfDownloader.isAcceptableContentType("text/html")).isFalse();

        assertThat(SafePdfDownloader.hasPdfMagic("%PDF-1.7".getBytes())).isTrue();
        assertThat(SafePdfDownloader.hasPdfMagic("<html>".getBytes())).isFalse();
        assertThat(SafePdfDownloader.hasPdfMagic(new byte[0])).isFalse();
    }

    @Test
    void translateSurfacesOwnExceptionsFromCauseChain() {
        RulebookUrlValidator.UnsafeUrlException unsafe = new RulebookUrlValidator.UnsafeUrlException("x");
        assertThat(SafePdfDownloader.translate(new RuntimeException("wrapped", unsafe))).isSameAs(unsafe);
        assertThat(SafePdfDownloader.translate(reactor.core.Exceptions.propagate(new TimeoutException())))
                .isInstanceOf(SafePdfDownloader.PdfDownloadException.class)
                .hasMessage("Download timed out");
    }
}
