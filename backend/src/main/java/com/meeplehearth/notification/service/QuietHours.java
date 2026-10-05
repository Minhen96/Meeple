package com.meeplehearth.notification.service;

import java.time.DateTimeException;
import java.time.Instant;
import java.time.LocalTime;
import java.time.ZoneId;

/**
 * A user's "Do Not Disturb" window (FEATURES_COMPLETE section 7.3), evaluated in their timezone.
 * The start is inclusive and the end exclusive; a window whose end is before its start spans
 * midnight (22:00–08:00). Equal start and end means an empty window.
 */
public record QuietHours(boolean enabled, LocalTime start, LocalTime end, ZoneId zone) {

    /** Region id {@code "UTC"} (not {@code ZoneOffset.UTC}, whose id is {@code "Z"}). */
    public static final ZoneId UTC = ZoneId.of("UTC");

    public static final QuietHours NONE = new QuietHours(false, null, null, UTC);

    public boolean isActive(Instant now) {
        if (!enabled || start == null || end == null || start.equals(end)) {
            return false;
        }
        LocalTime local = now.atZone(zone).toLocalTime();
        if (start.isBefore(end)) {
            return !local.isBefore(start) && local.isBefore(end);
        }
        return !local.isBefore(start) || local.isBefore(end);
    }

    /** The zone for an IANA id, or UTC when it is blank or unknown. */
    public static ZoneId zoneOrUtc(String zone) {
        if (zone == null || zone.isBlank()) {
            return UTC;
        }
        try {
            return ZoneId.of(zone.trim());
        } catch (DateTimeException e) {
            return UTC;
        }
    }
}
