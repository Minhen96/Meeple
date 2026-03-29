package com.meeplehearth.match.dto;

import jakarta.validation.constraints.NotNull;

import java.time.Instant;
import java.util.UUID;

public record CreateMatchRequestDto(
        @NotNull UUID gameId,
        Instant availableFrom,
        Instant availableTo
) {}
