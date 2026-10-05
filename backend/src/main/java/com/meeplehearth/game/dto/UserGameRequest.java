package com.meeplehearth.game.dto;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

/**
 * Partial update of a collection entry: only non-null fields are applied.
 * {@code personalRating} is 1–10; 0 clears the rating. If the update leaves every flag false and
 * no rating, notes or plays, the entry is deleted (FEATURES_COMPLETE section 3.1).
 */
public record UserGameRequest(
        Boolean isOwned,
        Boolean isWishlisted,
        Boolean isFavorited,
        @DecimalMin("0.0") @DecimalMax("10.0") BigDecimal personalRating,
        @Size(max = 1000) String notes
) {
}
