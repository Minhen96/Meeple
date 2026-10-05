package com.meeplehearth.search.dto;

import com.meeplehearth.game.dto.GameSummaryResponse;
import com.meeplehearth.social.dto.UserSummaryWithStatus;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/** {@code GET /api/v1/search}: up to {@code limit} matches per category (docs/GAP_ANALYSIS.md 6.1). */
public record SearchResponse(List<GameSummaryResponse> games,
                             List<UserSummaryWithStatus> users,
                             List<EventSummary> events) {

    /**
     * An event search hit. The location is deliberately omitted: public events reveal it only to
     * participants, so the event page decides what to show.
     */
    public record EventSummary(UUID id, String title, Instant scheduledAt, String status, String visibility,
                               GameRef game) {
    }

    public record GameRef(UUID id, String title, String thumbnailUrl) {
    }

    public static SearchResponse empty() {
        return new SearchResponse(List.of(), List.of(), List.of());
    }
}
