package com.meeplehearth.game.dto;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

// Partial update — only non-null fields are applied
public record UserGameRequest(
        Boolean isOwned,
        Boolean isFavorited,
        @DecimalMin("1.0") @DecimalMax("10.0") BigDecimal personalRating,
        @Size(max = 1000) String notes
) {
}
