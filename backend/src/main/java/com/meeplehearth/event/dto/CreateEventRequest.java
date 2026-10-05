package com.meeplehearth.event.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * {@code POST /api/v1/events}. Limits per FEATURES sections 4.1 and 12.1: title 1–100, description
 * ≤ 1000, location ≤ 100, max participants 2–50 (default 8), scheduledAt ≥ now − 5 min.
 * {@code invitedUserIds} must all be friends of the host and must not include the host.
 */
public record CreateEventRequest(
        @NotBlank @Size(max = 100) String title,
        @Size(max = 1000) String description,
        @Size(max = 100) String location,
        @Size(max = 100) String locationDisplay,
        @NotNull @NotInPastBeyondGrace Instant scheduledAt,
        UUID gameId,
        @Min(2) @Max(50) Integer maxParticipants,
        @NotNull @Pattern(regexp = "INVITE_ONLY|FRIENDS|PUBLIC") String visibility,
        @Size(max = 50) List<@NotNull UUID> invitedUserIds
) {
    public static final int DEFAULT_MAX_PARTICIPANTS = 8;

    public CreateEventRequest {
        invitedUserIds = invitedUserIds == null ? List.of() : invitedUserIds;
    }
}
