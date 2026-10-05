package com.meeplehearth.event.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.time.Instant;
import java.util.UUID;

/**
 * {@code PUT /api/v1/events/{id}}: every field is optional and only non-null fields change
 * (FEATURES section 4.4). An empty {@code description}, {@code location} or
 * {@code locationDisplay} clears that field. Same limits as {@link CreateEventRequest}.
 */
public record UpdateEventRequest(
        @Size(max = 100) @Pattern(regexp = "(?s).*\\S.*", message = "must not be blank") String title,
        @Size(max = 1000) String description,
        @Size(max = 100) String location,
        @Size(max = 100) String locationDisplay,
        @NotInPastBeyondGrace Instant scheduledAt,
        UUID gameId,
        @Min(2) @Max(50) Integer maxParticipants,
        @Pattern(regexp = "INVITE_ONLY|FRIENDS|PUBLIC") String visibility
) {
}
