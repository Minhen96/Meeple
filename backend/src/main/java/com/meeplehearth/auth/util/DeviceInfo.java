package com.meeplehearth.auth.util;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.web.context.request.RequestAttributes;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.util.Locale;

/**
 * Human-readable description of the device behind a session ("Chrome on macOS"), stored on the
 * refresh token for the Active Sessions screen. The raw User-Agent is never stored: it is a
 * fingerprinting aid and adds nothing the user can act on.
 *
 * <p>Native clients may send {@value #DEVICE_HEADER} (for example "Pixel 8 · Android 15");
 * it wins over the User-Agent after sanitising.
 */
public final class DeviceInfo {

    public static final String DEVICE_HEADER = "X-Device-Info";
    static final int MAX_LENGTH = 100;
    static final String UNKNOWN = "Unknown device";

    private DeviceInfo() {
    }

    /** Device description for the request currently being served, or null outside a request. */
    public static String fromCurrentRequest() {
        RequestAttributes attributes = RequestContextHolder.getRequestAttributes();
        if (attributes instanceof ServletRequestAttributes servlet) {
            return from(servlet.getRequest());
        }
        return null;
    }

    public static String from(HttpServletRequest request) {
        String declared = sanitize(request.getHeader(DEVICE_HEADER));
        if (declared != null) {
            return declared;
        }
        return describe(request.getHeader("User-Agent"));
    }

    /** Maps a User-Agent to "Browser on OS"; never returns null. */
    public static String describe(String userAgent) {
        if (userAgent == null || userAgent.isBlank()) {
            return UNKNOWN;
        }
        String ua = userAgent.toLowerCase(Locale.ROOT);
        String os = os(ua);
        String client = client(ua);
        if (client == null && os == null) {
            return UNKNOWN;
        }
        if (client == null) {
            return os;
        }
        return os == null ? client : client + " on " + os;
    }

    private static String os(String ua) {
        if (ua.contains("iphone") || ua.contains("ipad") || ua.contains("ios")) return "iOS";
        if (ua.contains("android")) return "Android";
        if (ua.contains("windows")) return "Windows";
        if (ua.contains("mac os") || ua.contains("macintosh")) return "macOS";
        if (ua.contains("cros")) return "ChromeOS";
        if (ua.contains("linux")) return "Linux";
        return null;
    }

    private static String client(String ua) {
        if (ua.contains("dart/") || ua.contains("meeple")) return "Meeple app";
        if (ua.contains("edg/")) return "Edge";
        if (ua.contains("opr/") || ua.contains("opera")) return "Opera";
        if (ua.contains("firefox/") || ua.contains("fxios")) return "Firefox";
        if (ua.contains("chrome/") || ua.contains("crios")) return "Chrome";
        if (ua.contains("safari/")) return "Safari";
        return null;
    }

    /** Keeps printable characters only and caps the length; null when nothing usable remains. */
    static String sanitize(String value) {
        if (value == null) {
            return null;
        }
        String cleaned = value.replaceAll("[\\p{Cntrl}<>\"]", "").trim();
        if (cleaned.isEmpty()) {
            return null;
        }
        return cleaned.length() > MAX_LENGTH ? cleaned.substring(0, MAX_LENGTH) : cleaned;
    }
}
