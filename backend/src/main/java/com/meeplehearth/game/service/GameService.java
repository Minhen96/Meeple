package com.meeplehearth.game.service;

import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.game.client.BggApiClient;
import com.meeplehearth.game.dto.*;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.entity.UserGame;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.game.repository.UserGameRepository;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
public class GameService {

    private final GameRepository gameRepository;
    private final UserGameRepository userGameRepository;
    private final UserRepository userRepository;
    private final BggApiClient bggApiClient;

    public GameService(GameRepository gameRepository,
                       UserGameRepository userGameRepository,
                       UserRepository userRepository,
                       BggApiClient bggApiClient) {
        this.gameRepository = gameRepository;
        this.userGameRepository = userGameRepository;
        this.userRepository = userRepository;
        this.bggApiClient = bggApiClient;
    }

    // -------------------------------------------------------------------------
    // Search — BGG + local cache overlay
    // -------------------------------------------------------------------------

    public List<GameSearchResult> search(String query) {
        List<BggApiClient.BggSearchResult> bggResults = bggApiClient.search(query);

        // Batch-load cached games by bggId to avoid N+1
        List<Long> bggIds = bggResults.stream().map(BggApiClient.BggSearchResult::bggId).toList();
        Map<Long, Game> cached = gameRepository.findByBggIdIn(bggIds).stream()
                .collect(Collectors.toMap(Game::getBggId, Function.identity()));

        return bggResults.stream().map(r -> {
            Game game = cached.get(r.bggId());
            return new GameSearchResult(
                    game != null ? game.getId() : null,
                    r.bggId(),
                    r.title(),
                    r.yearPublished(),
                    game != null ? game.getThumbnailUrl() : null
            );
        }).toList();
    }

    // -------------------------------------------------------------------------
    // Game detail — fetch from BGG and cache if not found locally
    // -------------------------------------------------------------------------

    public GameDetailResponse getGame(UUID gameId) {
        Game game = gameRepository.findById(gameId)
                .orElseThrow(() -> ApiException.notFound("GAME_NOT_FOUND", "Game not found"));
        return GameDetailResponse.from(game);
    }

    @Transactional
    public GameDetailResponse ensureGame(Long bggId) {
        return gameRepository.findByBggId(bggId)
                .map(GameDetailResponse::from)
                .orElseGet(() -> {
                    BggApiClient.BggGameDetail detail = bggApiClient.getDetail(bggId)
                            .orElseThrow(() -> ApiException.notFound("GAME_NOT_FOUND", "Game not found on BGG"));
                    Game game = mapToEntity(detail);
                    return GameDetailResponse.from(gameRepository.save(game));
                });
    }

    // -------------------------------------------------------------------------
    // Collection
    // -------------------------------------------------------------------------

    public List<UserGameResponse> getCollection(UUID userId, String filter) {
        List<UserGame> entries = switch (filter) {
            case "owned"      -> userGameRepository.findOwnedByUserId(userId);
            case "wishlisted" -> userGameRepository.findWishlistedByUserId(userId);
            case "favorited"  -> userGameRepository.findFavoritedByUserId(userId);
            default           -> userGameRepository.findAllByUserId(userId);
        };
        return entries.stream().map(UserGameResponse::from).toList();
    }

    @Transactional
    public UserGameResponse updateCollection(UUID userId, UUID gameId, UserGameRequest req) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> ApiException.notFound("User not found"));
        Game game = gameRepository.findById(gameId)
                .orElseThrow(() -> ApiException.notFound("GAME_NOT_FOUND", "Game not found"));

        UserGame ug = userGameRepository.findByUserIdAndGameId(userId, gameId)
                .orElseGet(() -> {
                    UserGame newUg = new UserGame();
                    newUg.setUser(user);
                    newUg.setGame(game);
                    return newUg;
                });

        ug.setOwned(req.isOwned());
        ug.setWishlisted(req.isWishlisted());
        ug.setFavorited(req.isFavorited());
        if (req.personalRating() != null) ug.setPersonalRating(req.personalRating());
        if (req.notes() != null)          ug.setNotes(req.notes());

        return UserGameResponse.from(userGameRepository.save(ug));
    }

    @Transactional
    public void removeFromCollection(UUID userId, UUID gameId) {
        UserGame ug = userGameRepository.findByUserIdAndGameId(userId, gameId)
                .orElseThrow(() -> ApiException.notFound("COLLECTION_ENTRY_NOT_FOUND", "Game not in collection"));
        userGameRepository.delete(ug);
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private Game mapToEntity(BggApiClient.BggGameDetail detail) {
        Game game = new Game();
        game.setBggId(detail.bggId());
        game.setTitle(detail.title());
        game.setThumbnailUrl(detail.thumbnailUrl());
        game.setImageUrl(detail.imageUrl());
        game.setDescription(detail.description());
        game.setYearPublished(detail.yearPublished());
        game.setMinPlayers(detail.minPlayers());
        game.setMaxPlayers(detail.maxPlayers());
        game.setMinPlaytime(detail.minPlaytime());
        game.setMaxPlaytime(detail.maxPlaytime());
        game.setBggRating(detail.bggRating());
        game.setComplexityWeight(detail.complexityWeight());
        return game;
    }
}
