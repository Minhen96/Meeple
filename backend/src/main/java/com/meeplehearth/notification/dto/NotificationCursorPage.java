package com.meeplehearth.notification.dto;

import java.util.List;

/**
 * Cursor page {@code {items, nextCursor, hasMore}}. {@code nextCursor} is opaque to clients: pass
 * it back unchanged as {@code ?cursor=}.
 */
public record NotificationCursorPage(List<NotificationResponse> items, String nextCursor, boolean hasMore) {
}
