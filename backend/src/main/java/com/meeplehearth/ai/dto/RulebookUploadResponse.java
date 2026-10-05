package com.meeplehearth.ai.dto;

import java.util.UUID;

/**
 * Response from POST /api/v1/games/{gameId}/rulebook (user PDF submission).
 *
 * @param status        "pending_review" | "already_done"
 * @param rulebookId    The submitted rulebook. Null for "already_done".
 * @param queuePosition Position in the game's review queue; may be null.
 */
public record RulebookUploadResponse(String status, UUID rulebookId, Integer queuePosition) {

    public static RulebookUploadResponse alreadyDone() {
        return new RulebookUploadResponse("already_done", null, null);
    }

    public static RulebookUploadResponse pendingReview(UUID rulebookId, Integer queuePosition) {
        return new RulebookUploadResponse("pending_review", rulebookId, queuePosition);
    }
}
