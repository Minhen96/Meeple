package com.meeplehearth.game.dto;

import java.util.List;

/** Cursor page, the same shape as the feed's ({@code {items, nextCursor, hasMore}}). */
public record CursorPage<T>(List<T> items, String nextCursor, boolean hasMore) {
}
