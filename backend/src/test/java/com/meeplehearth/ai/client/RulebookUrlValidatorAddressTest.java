package com.meeplehearth.ai.client;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.junit.jupiter.api.Test;

import java.net.InetAddress;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** Address classification and URL edge cases of the SSRF guard (complements RulebookUrlValidatorTest). */
class RulebookUrlValidatorAddressTest {

    private static InetAddress ip(String literal) throws Exception {
        return InetAddress.getByName(literal);
    }

    @ParameterizedTest
    @ValueSource(strings = {
            "0.1.2.3", "100.64.0.1", "100.127.255.254", "192.0.0.8", "198.18.0.1", "198.19.255.1",
            "240.0.0.1", "255.255.255.255", "127.0.0.1", "10.0.0.1", "172.16.0.1", "192.168.1.1",
            "169.254.169.254", "224.0.0.1", "0.0.0.0",
            "::1", "::", "fe80::1", "fc00::1", "fd12:3456::1", "ff02::1",
            "::ffff:10.0.0.1", "::ffff:127.0.0.1", "::7f00:1"})
    void nonPublicAddressesAreRejected(String literal) throws Exception {
        assertThat(RulebookUrlValidator.isPublicAddress(ip(literal))).as(literal).isFalse();
    }

    @ParameterizedTest
    @ValueSource(strings = {"8.8.8.8", "100.63.255.255", "100.128.0.1", "192.0.1.1", "198.20.0.1",
            "2606:4700::6810:84e5", "::ffff:104.18.10.20"})
    void publicAddressesAreAccepted(String literal) throws Exception {
        assertThat(RulebookUrlValidator.isPublicAddress(ip(literal))).as(literal).isTrue();
    }

    @Test
    void hostMatchingIsCaseInsensitiveAndIgnoresTrailingDot() {
        assertThat(RulebookUrlValidator.isAllowedHost("CDN.1J1JU.COM.")).isTrue();
        assertThat(RulebookUrlValidator.isAllowedHost("cf.geekdo-files.com")).isTrue();
        assertThat(RulebookUrlValidator.isAllowedHost("not1j1ju.com")).isFalse();
        assertThat(RulebookUrlValidator.isAllowedHost("1j1ju.com.evil.org")).isFalse();
    }

    @Test
    void malformedOrHostlessUrlsAreRejected() {
        RulebookUrlValidator validator = new RulebookUrlValidator(host -> new InetAddress[]{ipUnchecked("8.8.8.8")});
        assertThat(validator.isAllowedSyntax(" ")).isFalse();
        assertThat(validator.isAllowedSyntax("https://cdn.1j1ju.com/a b.pdf")).isFalse();
        assertThat(validator.isAllowedSyntax("https:///no-host.pdf")).isFalse();
        assertThat(validator.isAllowedSyntax("https://cdn.1j1ju.com:443/a.pdf")).isTrue();
        assertThat(validator.validate("  https://cdn.1j1ju.com/x/../a.pdf ").getPath()).isEqualTo("/a.pdf");
    }

    @Test
    void emptyDnsAnswerIsRejected() {
        RulebookUrlValidator empty = new RulebookUrlValidator(host -> new InetAddress[0]);
        assertThatThrownBy(() -> empty.validate("https://cdn.1j1ju.com/a.pdf"))
                .isInstanceOf(RulebookUrlValidator.UnsafeUrlException.class)
                .hasMessageContaining("could not be resolved");
        RulebookUrlValidator nullAnswer = new RulebookUrlValidator(host -> null);
        assertThatThrownBy(() -> nullAnswer.validate("https://cdn.1j1ju.com/a.pdf"))
                .isInstanceOf(RulebookUrlValidator.UnsafeUrlException.class);
    }

    @Test
    void contentTypeAndMagicHelpers() {
        assertThat(SafePdfDownloader.isAcceptableContentType(null)).isTrue();
        assertThat(SafePdfDownloader.isAcceptableContentType("Application/PDF; charset=binary")).isTrue();
        assertThat(SafePdfDownloader.isAcceptableContentType("application/x-pdf")).isTrue();
        assertThat(SafePdfDownloader.isAcceptableContentType("text/plain")).isFalse();
        assertThat(SafePdfDownloader.hasPdfMagic(null)).isFalse();
        assertThat(SafePdfDownloader.hasPdfMagic("%PD".getBytes())).isFalse();
        assertThat(SafePdfDownloader.hasPdfMagic("%PDF".getBytes())).isTrue();
    }

    private static InetAddress ipUnchecked(String literal) {
        try {
            return ip(literal);
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }
}
