package com.meeplehearth.game.dto;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

// Multi-boolean collection update — any combination of flags may be set
public record UserGameRequest(
        boolean isOwned,
        boolean isWishlisted,
        boolean isFavorited,
        @DecimalMin("1.0") @DecimalMax("10.0") BigDecimal personalRating,
        @Size(max = 1000) String notes
) {
}
