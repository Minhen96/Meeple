package com.meeplehearth.user.dto;

import com.meeplehearth.user.entity.DataExportRequest;

import java.time.Instant;
import java.util.UUID;

/** POST /api/v1/users/me/export (202). The download link is emailed once the export completes. */
public record DataExportResponse(UUID id, String status, Instant createdAt, Instant completedAt) {

    public static DataExportResponse from(DataExportRequest request) {
        return new DataExportResponse(request.getId(), request.getStatus().name(),
                request.getCreatedAt(), request.getCompletedAt());
    }
}
