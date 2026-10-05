package com.meeplehearth.ai.client;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import java.net.InetAddress;
import java.net.URI;
import java.net.UnknownHostException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class RulebookUrlValidatorTest {

    private static InetAddress ip(String literal) {
        try {
            return InetAddress.getByName(literal); // literal IPs: no DNS lookup
        } catch (UnknownHostException e) {
            throw new IllegalStateException(e);
        }
    }

    private static RulebookUrlValidator resolvingTo(String... ips) {
        return new RulebookUrlValidator(host -> {
            InetAddress[] out = new InetAddress[ips.length];
            for (int i = 0; i < ips.length; i++) out[i] = ip(ips[i]);
            return out;
        });
    }

    @Test
    void acceptsAllowlistedHttpsHostResolvingToPublicIp() {
        RulebookUrlValidator validator = resolvingTo("104.18.10.20");

        URI uri = validator.validate("https://cdn.1j1ju.com/medias/7a/18/fd-catan-rulebook.pdf");

        assertThat(uri.getHost()).isEqualTo("cdn.1j1ju.com");
    }

    @ParameterizedTest
    @ValueSource(strings = {
            "https://cdn.1j1ju.com/a.pdf",
            "https://api.rule-book.org/games",
            "https://boardgamegeek.com/dl/filepage/1/x.pdf",
            "https://cf.geekdo-images.com/x.pdf",
            "https://cf.geekdo-files.com/x.pdf",
            "https://CDN.1J1JU.COM/a.pdf"
    })
    void acceptsEveryAllowlistedHost(String url) {
        assertThat(resolvingTo("151.101.1.1").validate(url)).isNotNull();
    }

    @Test
    void rejectsPlainHttp() {
        RulebookUrlValidator validator = resolvingTo("104.18.10.20");

        assertThatThrownBy(() -> validator.validate("http://cdn.1j1ju.com/a.pdf"))
                .isInstanceOf(RulebookUrlValidator.UnsafeUrlException.class)
                .hasMessageContaining("https");
    }

    @ParameterizedTest
    @ValueSource(strings = {
            "https://evil.example.com/a.pdf",
            "https://cdn.1j1ju.com.evil.com/a.pdf",
            "https://not1j1ju.com/a.pdf",
            "https://169.254.169.254/latest/meta-data",
            "https://localhost/a.pdf"
    })
    void rejectsNonAllowlistedHosts(String url) {
        RulebookUrlValidator validator = resolvingTo("104.18.10.20");

        assertThatThrownBy(() -> validator.validate(url))
                .isInstanceOf(RulebookUrlValidator.UnsafeUrlException.class);
    }

    @ParameterizedTest
    @ValueSource(strings = {
            "127.0.0.1", "10.0.0.5", "172.16.3.4", "192.168.1.1", "169.254.169.254",
            "100.64.0.1", "0.0.0.0", "224.0.0.1", "::1", "fd00::1", "fe80::1", "::ffff:10.0.0.1"
    })
    void rejectsAllowlistedHostResolvingToPrivateAddress(String privateIp) {
        RulebookUrlValidator validator = resolvingTo(privateIp);

        assertThatThrownBy(() -> validator.validate("https://cdn.1j1ju.com/a.pdf"))
                .isInstanceOf(RulebookUrlValidator.UnsafeUrlException.class)
                .hasMessageContaining("non-public");
    }

    @Test
    void rejectsWhenAnyResolvedAddressIsPrivate() {
        RulebookUrlValidator validator = resolvingTo("104.18.10.20", "10.0.0.1");

        assertThatThrownBy(() -> validator.validate("https://cdn.1j1ju.com/a.pdf"))
                .isInstanceOf(RulebookUrlValidator.UnsafeUrlException.class);
    }

    @Test
    void rejectsUserInfoAndNonStandardPort() {
        RulebookUrlValidator validator = resolvingTo("104.18.10.20");

        assertThatThrownBy(() -> validator.validate("https://user:pw@cdn.1j1ju.com/a.pdf"))
                .isInstanceOf(RulebookUrlValidator.UnsafeUrlException.class);
        assertThatThrownBy(() -> validator.validate("https://cdn.1j1ju.com:8443/a.pdf"))
                .isInstanceOf(RulebookUrlValidator.UnsafeUrlException.class);
    }

    @Test
    void rejectsUnresolvableHost() {
        RulebookUrlValidator validator = new RulebookUrlValidator(host -> {
            throw new UnknownHostException(host);
        });

        assertThatThrownBy(() -> validator.validate("https://cdn.1j1ju.com/a.pdf"))
                .isInstanceOf(RulebookUrlValidator.UnsafeUrlException.class);
    }

    @Test
    void syntaxCheckDoesNotResolveDns() {
        RulebookUrlValidator validator = new RulebookUrlValidator(host -> {
            throw new AssertionError("DNS must not be used by isAllowedSyntax");
        });

        assertThat(validator.isAllowedSyntax("https://cdn.1j1ju.com/a.pdf")).isTrue();
        assertThat(validator.isAllowedSyntax("http://cdn.1j1ju.com/a.pdf")).isFalse();
        assertThat(validator.isAllowedSyntax("https://evil.com/a.pdf")).isFalse();
        assertThat(validator.isAllowedSyntax(null)).isFalse();
    }
}
