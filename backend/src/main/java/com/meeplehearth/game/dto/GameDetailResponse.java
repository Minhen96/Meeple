package com.meeplehearth.game.dto;

import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.entity.GameDetail;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

/**
 * Game detail. The catalog part is the same for every viewer and is cached ("game-detail");
 * {@code friendAvgRating}, {@code friendRatingCount} and {@code ownedByFriends} are computed per
 * viewer on every request ({@link #withFriendData}) and are null in the cached copy.
 */
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
        boolean hasRulebook,
        BigDecimal friendAvgRating,
        int friendRatingCount,
        List<UserSummary> ownedByFriends
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
                hasRulebook,
                null,
                0,
                null
        );
    }

    /** This detail with the viewer's friend data (ownedByFriends: at most 5). */
    public GameDetailResponse withFriendData(BigDecimal avgRating, int ratingCount, List<UserSummary> owners) {
        return new GameDetailResponse(id, bggId, title, thumbnailUrl, imageUrl, description, yearPublished,
                minPlayers, maxPlayers, playTime, minAge, complexityWeight, bggRating, usersRated, rank,
                ownedCount, gameType, bggUrl, categories, mechanics, families, designers, publishers, honors,
                expansions, hasRulebook, avgRating, ratingCount, owners == null ? List.of() : List.copyOf(owners));
    }
}
