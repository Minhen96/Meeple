package com.meeplehearth.event.dto;

import jakarta.validation.constraints.Future;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.Instant;
import java.util.UUID;

public record CreateEventRequest(
        @NotBlank @Size(min = 3, max = 100) String title,
        @Size(max = 1000) String description,
        @Size(max = 200) String location,
        @NotNull @Future Instant scheduledAt,
        UUID gameId,
        Integer maxPlayers,
        boolean isPublic
) {
}
