package com.meeplehearth.feed.dto;

import java.util.List;

/**
 * Cursor page for live lists (feed, bookmarks, event memories): {@code {items, nextCursor, hasMore}}.
 * Pass {@code nextCursor} back as {@code ?cursor=} for the following page; it is opaque.
 */
public record CursorPage<T>(List<T> items, String nextCursor, boolean hasMore) {

    public CursorPage {
        items = List.copyOf(items);
    }

    public static <T> CursorPage<T> empty() {
        return new CursorPage<>(List.of(), null, false);
    }
}
