package com.meeplehearth.game.dto;

import java.math.BigDecimal;

/** A friend's rating and notes for a game ({@code GET /games/{id}/reviews}). */
public record GameReviewResponse(UserSummary user, BigDecimal personalRating, String notes, int playCount) {
}
