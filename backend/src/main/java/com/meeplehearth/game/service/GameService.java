package com.meeplehearth.game.service;

import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.game.client.BggApiClient;
import com.meeplehearth.game.dto.*;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.entity.GameDetail;
import com.meeplehearth.game.entity.UserGame;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.game.repository.UserGameRepository;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import jakarta.persistence.criteria.Join;

import java.util.List;
import java.util.UUID;

@Service
public class GameService {

    private final GameRepository gameRepository;
    private final UserGameRepository userGameRepository;
    private final UserRepository userRepository;
    private final BggApiClient bggApiClient;
    private final GameHydrationService gameHydrationService;

    public GameService(GameRepository gameRepository,
                       UserGameRepository userGameRepository,
                       UserRepository userRepository,
                       BggApiClient bggApiClient,
                       GameHydrationService gameHydrationService) {
        this.gameRepository = gameRepository;
        this.userGameRepository = userGameRepository;
        this.userRepository = userRepository;
        this.bggApiClient = bggApiClient;
        this.gameHydrationService = gameHydrationService;
    }

    // -------------------------------------------------------------------------
    // Browse - Local DB with dynamic filters
    // -------------------------------------------------------------------------

    public Page<GameSummaryResponse> browse(String query, Integer minPlayers, Integer maxPlayers,
                                            Integer minPlaytime, Integer maxPlaytime,
                                            java.math.BigDecimal minComplexity, java.math.BigDecimal maxComplexity,
                                            java.math.BigDecimal minRating, Pageable pageable) {
        Specification<Game> spec = Specification.where(
                (root, cq, cb) -> cb.equal(root.get("gameType"), "boardgame")
        );
        if (query != null && !query.isBlank()) {
            String likeQ = "%" + query.toLowerCase() + "%";
            spec = spec.and((root, cq, cb) -> cb.or(
                    cb.like(cb.lower(root.get("nameEn")), likeQ),
                    cb.like(cb.lower(root.get("nameZh")), likeQ)
            ));
        }
        if (minPlayers != null) {
            spec = spec.and((root, cq, cb) -> cb.le(root.get("minPlayers"), minPlayers));
        }
        if (maxPlayers != null) {
            spec = spec.and((root, cq, cb) -> cb.ge(root.get("maxPlayers"), maxPlayers));
        }
        if (minPlaytime != null) {
            spec = spec.and((root, cq, cb) -> cb.ge(root.get("playTime"), minPlaytime));
        }
        if (maxPlaytime != null) {
            spec = spec.and((root, cq, cb) -> cb.le(root.get("playTime"), maxPlaytime));
        }
        if (minRating != null) {
            spec = spec.and((root, cq, cb) -> cb.ge(root.get("bggRating"), minRating));
        }
        if (minComplexity != null || maxComplexity != null) {
            spec = spec.and((root, cq, cb) -> {
                Join<Game, com.meeplehearth.game.entity.GameDetail> join = root.join("gameDetail");
                if (minComplexity != null && maxComplexity != null) {
                    return cb.between(join.get("complexity"), minComplexity, maxComplexity);
                } else if (minComplexity != null) {
                    return cb.ge(join.get("complexity"), minComplexity);
                } else {
                    return cb.le(join.get("complexity"), maxComplexity);
                }
            });
        }
        Page<Game> gamePage = gameRepository.findAll(spec, pageable);

        // Async Hydration — trigger for games not yet hydrated from BGG
        List<Long> requireHydration = gamePage.getContent().stream()
                .filter(g -> g.getMinPlayers() == null)
                .map(Game::getBggId)
                .toList();
        if (!requireHydration.isEmpty()) {
            gameHydrationService.hydrateImagesQuietly(requireHydration);
        }

        return gamePage.map(GameSummaryResponse::from);
    }

    // -------------------------------------------------------------------------
    // Search — local DB (BGG search API requires auth since 2025)

    public List<GameSearchResult> search(String query) {
        if (query == null || query.isBlank()) return List.of();
        String likeQ = "%" + query.toLowerCase() + "%";
        Specification<Game> spec = Specification.<Game>where(
                (root, cq, cb) -> cb.or(
                        cb.like(cb.lower(root.get("nameEn")), likeQ),
                        cb.like(cb.lower(root.get("nameZh")), likeQ)
                )
        ).and((root, cq, cb) -> cb.equal(root.get("gameType"), "boardgame"));

        return gameRepository.findAll(spec, org.springframework.data.domain.PageRequest.of(0, 20))
                .stream()
                .map(g -> new GameSearchResult(
                        g.getId(), g.getBggId(), g.getNameEn(),
                        g.getYearPublished(), g.getThumbnailUrl()))
                .toList();
    }

    // -------------------------------------------------------------------------
    // Game detail — fetch from BGG and cache if not found locally
    // -------------------------------------------------------------------------

    @Transactional
    public GameDetailResponse getGame(UUID gameId) {
        Game game = gameRepository.findById(gameId)
                .orElseThrow(() -> ApiException.notFound("GAME_NOT_FOUND", "Game not found"));
        if (game.getMinPlayers() == null) {
            gameHydrationService.hydrateImageSync(game);
        }
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

        if (req.isOwned() != null)        ug.setOwned(req.isOwned());
        if (req.isWishlisted() != null)   ug.setWishlisted(req.isWishlisted());
        if (req.isFavorited() != null)    ug.setFavorited(req.isFavorited());
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
        game.setNameEn(detail.title());
        game.setThumbnailUrl(detail.thumbnailUrl());
        game.setImageUrl(detail.imageUrl());
        game.setYearPublished(detail.yearPublished());
        game.setMinPlayers(detail.minPlayers());
        game.setMaxPlayers(detail.maxPlayers());
        game.setPlayTime(detail.maxPlaytime());
        game.setBggRating(detail.bggRating());

        GameDetail gDetail = new GameDetail();
        gDetail.setGame(game);
        gDetail.setDescription(detail.description());
        gDetail.setComplexity(detail.complexityWeight());
        game.setGameDetail(gDetail);

        return game;
    }
}
