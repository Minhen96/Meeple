package com.meeplehearth.game.dto;

import com.fasterxml.jackson.annotation.JsonIgnore;

import java.util.List;
import java.util.UUID;

/**
 * Progress of the caller's BGG collection import ({@code GET /users/me/bgg-import/status}).
 *
 * @param status    "idle" | "running" | "done" | "failed"
 * @param errorCode set when failed: BGG_USER_NOT_FOUND | BGG_API_UNAVAILABLE
 * @param preview   up to 5 imported games, for the success screen
 */
public record BggImportStatusResponse(
        String status,
        int total,
        int processed,
        int imported,
        int skipped,
        int failed,
        String errorCode,
        List<PreviewGame> preview
) {
    public static final String IDLE = "idle";
    public static final String RUNNING = "running";
    public static final String DONE = "done";
    public static final String FAILED = "failed";

    public BggImportStatusResponse {
        preview = preview == null ? List.of() : List.copyOf(preview);
    }

    public static BggImportStatusResponse idle() {
        return new BggImportStatusResponse(IDLE, 0, 0, 0, 0, 0, null, List.of());
    }

    public static BggImportStatusResponse running() {
        return new BggImportStatusResponse(RUNNING, 0, 0, 0, 0, 0, null, List.of());
    }

    public static BggImportStatusResponse failed(String errorCode) {
        return new BggImportStatusResponse(FAILED, 0, 0, 0, 0, 0, errorCode, List.of());
    }

    @JsonIgnore
    public boolean isRunning() {
        return RUNNING.equals(status);
    }

    public record PreviewGame(UUID gameId, String title, String thumbnailUrl) {
    }
}
