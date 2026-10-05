package com.meeplehearth.event.dto;

import java.util.List;

/**
 * Cursor page ({@code GET /api/v1/events/community}): same shape as the shared web
 * {@code CursorPage<T>} type. Pass {@code nextCursor} back as {@code cursor} for the next page.
 */
public record EventPageResponse(List<EventResponse> items, String nextCursor, boolean hasMore) {
}
