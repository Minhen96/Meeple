package com.meeplehearth.ai.client;

import org.springframework.stereotype.Component;

import java.net.Inet4Address;
import java.net.Inet6Address;
import java.net.InetAddress;
import java.net.URI;
import java.net.UnknownHostException;
import java.util.List;
import java.util.Locale;

/**
 * SSRF guard for every rulebook URL the server downloads.
 *
 * A URL is accepted only if:
 *   - scheme is https, no user-info, default port (or 443)
 *   - host is (a subdomain of) one of the allowlisted rulebook hosts actually
 *     used by our clients (1j1ju CDN, rule-book.org, 1jour-1jeu, BGG/geekdo)
 *   - every address the host resolves to is a public unicast address
 *     (no loopback / link-local / site-local / CGNAT / ULA / multicast / any-local)
 */
@Component
public class RulebookUrlValidator {

    /** Registrable domains; a host matches if it equals one or is a subdomain of one. */
    static final List<String> ALLOWED_DOMAINS = List.of(
            "1j1ju.com",           // cdn.1j1ju.com — links returned by rule-book.org and 1jour-1jeu
            "rule-book.org",       // api.rule-book.org
            "1jour-1jeu.com",      // en.1jour-1jeu.com
            "boardgamegeek.com",   // BGG filepage / dl links
            "geekdo.com",          // api.geekdo.com
            "geekdo-images.com",   // cf.geekdo-images.com
            "geekdo-files.com"     // cf.geekdo-files.com (BGG file downloads)
    );

    /** DNS resolution hook — replaceable in tests. */
    @FunctionalInterface
    public interface HostResolver {
        InetAddress[] resolve(String host) throws UnknownHostException;
    }

    private final HostResolver resolver;

    public RulebookUrlValidator() {
        this(InetAddress::getAllByName);
    }

    public RulebookUrlValidator(HostResolver resolver) {
        this.resolver = resolver;
    }

    /** The resolver used for validation; downloads resolve through it again at connect time. */
    HostResolver hostResolver() {
        return resolver;
    }

    /**
     * Syntax + allowlist check only (no DNS). Used to reject obviously bad URLs
     * before they are persisted.
     */
    public boolean isAllowedSyntax(String url) {
        try {
            checkSyntax(parse(url));
            return true;
        } catch (UnsafeUrlException e) {
            return false;
        }
    }

    /**
     * Full validation including DNS resolution. Returns the parsed URI.
     *
     * @throws UnsafeUrlException if the URL must not be fetched
     */
    public URI validate(String url) {
        URI uri = parse(url);
        checkSyntax(uri);
        checkResolvedAddresses(uri.getHost());
        return uri;
    }

    // -------------------------------------------------------------------------

    private URI parse(String url) {
        if (url == null || url.isBlank()) throw new UnsafeUrlException("Empty URL");
        try {
            return new URI(url.strip()).normalize();
        } catch (Exception e) {
            throw new UnsafeUrlException("Malformed URL");
        }
    }

    private void checkSyntax(URI uri) {
        if (!"https".equalsIgnoreCase(uri.getScheme())) {
            throw new UnsafeUrlException("Only https URLs are allowed");
        }
        if (uri.getRawUserInfo() != null) {
            throw new UnsafeUrlException("User-info in URL is not allowed");
        }
        if (uri.getPort() != -1 && uri.getPort() != 443) {
            throw new UnsafeUrlException("Non-standard port is not allowed");
        }
        String host = uri.getHost();
        if (host == null || host.isBlank()) {
            throw new UnsafeUrlException("URL has no host");
        }
        if (!isAllowedHost(host)) {
            throw new UnsafeUrlException("Host is not on the rulebook allowlist: " + host);
        }
    }

    static boolean isAllowedHost(String host) {
        String h = host.toLowerCase(Locale.ROOT);
        if (h.endsWith(".")) h = h.substring(0, h.length() - 1);
        for (String domain : ALLOWED_DOMAINS) {
            if (h.equals(domain) || h.endsWith("." + domain)) return true;
        }
        return false;
    }

    private void checkResolvedAddresses(String host) {
        InetAddress[] addresses;
        try {
            addresses = resolver.resolve(host);
        } catch (UnknownHostException e) {
            throw new UnsafeUrlException("Host could not be resolved: " + host);
        }
        if (addresses == null || addresses.length == 0) {
            throw new UnsafeUrlException("Host could not be resolved: " + host);
        }
        for (InetAddress addr : addresses) {
            if (!isPublicAddress(addr)) {
                throw new UnsafeUrlException("Host resolves to a non-public address: " + host);
            }
        }
    }

    static boolean isPublicAddress(InetAddress addr) {
        if (addr.isAnyLocalAddress() || addr.isLoopbackAddress() || addr.isLinkLocalAddress()
                || addr.isSiteLocalAddress() || addr.isMulticastAddress()) {
            return false;
        }
        byte[] b = addr.getAddress();
        if (addr instanceof Inet4Address) {
            int b0 = b[0] & 0xFF;
            int b1 = b[1] & 0xFF;
            if (b0 == 0) return false;                                  // 0.0.0.0/8
            if (b0 == 100 && b1 >= 64 && b1 <= 127) return false;       // 100.64.0.0/10 CGNAT
            if (b0 == 192 && b1 == 0 && (b[2] & 0xFF) == 0) return false; // 192.0.0.0/24
            if (b0 == 198 && (b1 == 18 || b1 == 19)) return false;      // 198.18.0.0/15
            if (b0 >= 240) return false;                                // reserved + broadcast
            return true;
        }
        if (addr instanceof Inet6Address) {
            int b0 = b[0] & 0xFF;
            if ((b0 & 0xFE) == 0xFC) return false;                      // fc00::/7 unique-local
            // IPv4-mapped (::ffff:a.b.c.d) and IPv4-compatible (::a.b.c.d) addresses
            boolean firstTenZero = true;
            for (int i = 0; i < 10; i++) {
                if (b[i] != 0) { firstTenZero = false; break; }
            }
            if (firstTenZero && ((b[10] == 0 && b[11] == 0) || (b[10] == (byte) 0xFF && b[11] == (byte) 0xFF))) {
                try {
                    InetAddress v4 = InetAddress.getByAddress(new byte[]{b[12], b[13], b[14], b[15]});
                    return isPublicAddress(v4);
                } catch (UnknownHostException e) {
                    return false;
                }
            }
            return true;
        }
        return false;
    }

    /** Thrown when a URL must not be fetched. */
    public static class UnsafeUrlException extends RuntimeException {
        public UnsafeUrlException(String message) {
            super(message);
        }
    }
}
