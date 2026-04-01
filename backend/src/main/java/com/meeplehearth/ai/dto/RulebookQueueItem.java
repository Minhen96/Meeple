package com.meeplehearth.ai.dto;

import com.meeplehearth.ai.entity.GameRulebook;

import java.time.Instant;
import java.util.UUID;

/**
 * Admin queue list item — one pending rulebook submission.
 */
public record RulebookQueueItem(
        UUID id,
        UUID gameId,
        String gameName,
        String source,
        String fileUrl,        // pdfUrl (auto-fetch) or publicUrl (upload)
        String uploaderUsername,
        Integer queuePosition,
        Instant createdAt
) {
    public static RulebookQueueItem from(GameRulebook r) {
        String fileUrl = r.getPdfUrl() != null ? r.getPdfUrl() : r.getPublicUrl();
        String uploader = r.getUploadedBy() != null ? r.getUploadedBy().getUsername() : null;
        return new RulebookQueueItem(
                r.getId(),
                r.getGame().getId(),
                r.getGame().getNameEn(),
                r.getSource(),
                fileUrl,
                uploader,
                r.getQueuePosition(),
                r.getCreatedAt()
        );
    }
}
