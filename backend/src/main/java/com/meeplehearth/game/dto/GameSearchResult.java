package com.meeplehearth.game.dto;

import java.util.UUID;

// Lightweight search result — id/thumbnailUrl are null if not yet cached in our DB
// translatedFrom is non-null when the original query was CJK and was auto-translated
public record GameSearchResult(
        UUID id,
        Long bggId,
        String title,
        Integer yearPublished,
        String thumbnailUrl,
        String translatedFrom
) {
}
