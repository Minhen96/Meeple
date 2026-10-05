package com.meeplehearth.feed.dto;

import com.meeplehearth.social.dto.UserSummary;

import java.util.Map;
import java.util.UUID;

/**
 * A feed activity: {@code type} is {@code collection_add} | {@code event_created} | {@code event_joined}.
 * {@code data} is the recorded payload enriched at read time with current display fields:
 * {@code gameName}, {@code gameThumbnailUrl} (when the payload has {@code gameId}) and
 * {@code eventTitle}, {@code eventScheduledAt} (when it has {@code eventId}).
 */
public record ActivityResponse(UUID id, String type, UserSummary user, Map<String, Object> data) {
}
