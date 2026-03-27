package com.meeplehearth.game.dto;

// Multi-boolean collection update — any combination of flags may be set
public record UserGameRequest(
        boolean isOwned,
        boolean isWishlisted,
        boolean isFavorited
) {
}
