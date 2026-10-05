package com.meeplehearth.common.event;

import java.time.Instant;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

/**
 * A user did something that appears as an activity item in friends' feeds.
 *
 * <p>Published with {@code ApplicationEventPublisher} by the events package ({@code event_created},
 * {@code event_joined}) and the library package ({@code collection_add}); consumed by the feed
 * package with {@code @TransactionalEventListener(phase = AFTER_COMMIT)}.
 *
 * @param userId the acting user
 * @param type   {@link #COLLECTION_ADD} | {@link #EVENT_CREATED} | {@link #EVENT_JOINED}
 * @param data   type-specific payload (for example {@code gameId}, {@code eventId}); never null
 * @param at     when the activity happened
 */
public record ActivityRecordedEvent(UUID userId, String type, Map<String, Object> data, Instant at) {

    public static final String COLLECTION_ADD = "collection_add";
    public static final String EVENT_CREATED = "event_created";
    public static final String EVENT_JOINED = "event_joined";

    public ActivityRecordedEvent {
        // Copy defensively; unlike Map.copyOf this tolerates null values in the payload.
        data = data == null ? Map.of() : Collections.unmodifiableMap(new LinkedHashMap<>(data));
    }
}
