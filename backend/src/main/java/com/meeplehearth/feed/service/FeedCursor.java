package com.meeplehearth.feed.service;

import com.meeplehearth.common.exception.ApiException;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.format.DateTimeParseException;
import java.util.Base64;
import java.util.UUID;

/**
 * Keyset cursor over {@code (created_at DESC, id DESC)}: the next page holds rows strictly before
 * {@code (at, id)}. Encoded as opaque base64url of {@code "<ISO instant>|<uuid>"} so ties on the
 * timestamp never skip or repeat rows.
 *
 * <p>A bare ISO-8601 instant (FEATURES_COMPLETE 5.5) is also accepted and means "strictly older
 * than this instant" (paired with the smallest UUID).
 */
public record FeedCursor(Instant at, UUID id) {

    static final UUID MIN_UUID = new UUID(0L, 0L);

    public String encode() {
        String raw = at.toString() + "|" + id;
        return Base64.getUrlEncoder().withoutPadding().encodeToString(raw.getBytes(StandardCharsets.UTF_8));
    }

    public static String encode(Instant at, UUID id) {
        return new FeedCursor(at, id).encode();
    }

    /** Parses a client cursor; {@code null} or blank means the first page. */
    public static FeedCursor parse(String cursor) {
        if (cursor == null || cursor.isBlank()) {
            return null;
        }
        String trimmed = cursor.trim();
        try {
            return new FeedCursor(Instant.parse(trimmed), MIN_UUID);
        } catch (DateTimeParseException ignored) {
            // not a bare instant; try the opaque form
        }
        try {
            String raw = new String(Base64.getUrlDecoder().decode(trimmed), StandardCharsets.UTF_8);
            int bar = raw.indexOf('|');
            if (bar > 0) {
                return new FeedCursor(Instant.parse(raw.substring(0, bar)), UUID.fromString(raw.substring(bar + 1)));
            }
        } catch (IllegalArgumentException | DateTimeParseException ignored) {
            // fall through to the error below
        }
        throw ApiException.badRequest("INVALID_CURSOR", "Invalid cursor");
    }
}
