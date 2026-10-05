package com.meeplehearth.game.dto;

import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.entity.GameDetail;

import java.math.BigDecimal;
import java.util.UUID;

public record GameDetailResponse(
        UUID id,
        Long bggId,
        String title,
        String thumbnailUrl,
        String imageUrl,
        String description,
        Integer yearPublished,
        Integer minPlayers,
        Integer maxPlayers,
        Integer playTime,
        Integer minAge,
        BigDecimal complexityWeight,
        BigDecimal bggRating,
        Integer usersRated,
        Integer rank,
        Integer ownedCount,
        String gameType,
        String bggUrl,
        String[] categories,
        String[] mechanics,
        String[] families,
        String[] designers,
        String[] publishers,
        String[] honors,
        String[] expansions,
        boolean hasRulebook
) {
    /** Use when rulebook status is unknown (e.g. ensureGame — not yet in collection). */
    public static GameDetailResponse from(Game game, GameDetail d) {
        return from(game, d, false);
    }

    /** {@code d} may be null when the game has no game_details row yet. */
    public static GameDetailResponse from(Game game, GameDetail d, boolean hasRulebook) {
        return new GameDetailResponse(
                game.getId(),
                game.getBggId(),
                game.getNameEn(),
                game.getThumbnailUrl(),
                game.getImageUrl(),
                d != null ? d.getDescription() : null,
                game.getYearPublished(),
                game.getMinPlayers(),
                game.getMaxPlayers(),
                game.getPlayTime(),
                game.getMinAge(),
                d != null ? d.getComplexity() : null,
                game.getBggRating(),
                game.getUsersRated(),
                game.getRank(),
                d != null ? d.getOwned() : null,
                game.getGameType(),
                d != null ? d.getBggUrl() : null,
                d != null ? d.getCategories() : null,
                d != null ? d.getMechanics() : null,
                d != null ? d.getFamilies() : null,
                d != null ? d.getDesigners() : null,
                d != null ? d.getPublishers() : null,
                d != null ? d.getHonors() : null,
                d != null ? d.getExpansions() : null,
                hasRulebook
        );
    }
}
