package com.meeplehearth.common.dto;

/**
 * Pagination metadata.
 * Shape: { "page": 1, "limit": 20, "total": 150, "hasMore": true }
 */
public record PageMeta(int page, int limit, long total, boolean hasMore) {
}
