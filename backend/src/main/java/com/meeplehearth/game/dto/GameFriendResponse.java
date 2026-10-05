package com.meeplehearth.game.dto;

import java.math.BigDecimal;

/** A friend who owns a game ({@code GET /games/{id}/friends}). */
public record GameFriendResponse(UserSummary user, int playCount, BigDecimal personalRating, boolean isOwned) {
}
