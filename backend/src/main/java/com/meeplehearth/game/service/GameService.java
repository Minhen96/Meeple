package com.meeplehearth.game.service;

import com.meeplehearth.ai.repository.GameRulebookRepository;
import com.meeplehearth.ai.service.SearchTranslationService;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.game.client.BggApiClient;
import com.meeplehearth.game.dto.*;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.entity.GameDetail;
import com.meeplehearth.game.entity.PlayLog;
import com.meeplehearth.game.entity.UserGame;
import com.meeplehearth.event.repository.EventParticipantRepository;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.game.repository.PlayLogRepository;
import com.meeplehearth.game.repository.UserGameRepository;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import jakarta.persistence.criteria.Join;
import jakarta.persistence.criteria.Predicate;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;

@Service
public class GameService {

    private final GameRepository gameRepository;
    private final UserGameRepository userGameRepository;
    private final PlayLogRepository playLogRepository;
    private final UserRepository userRepository;
    private final BggApiClient bggApiClient;
    private final GameHydrationService gameHydrationService;
    private final SearchTranslationService searchTranslationService;
    private final RecommendationService recommendationService;
    private final GameRulebookRepository rulebookRepository;
    private final EventParticipantRepository eventParticipantRepository;

    public GameService(GameRepository gameRepository,
            UserGameRepository userGameRepository,
            PlayLogRepository playLogRepository,
            UserRepository userRepository,
            BggApiClient bggApiClient,
            GameHydrationService gameHydrationService,
            SearchTranslationService searchTranslationService,
            RecommendationService recommendationService,
            GameRulebookRepository rulebookRepository,
            EventParticipantRepository eventParticipantRepository) {
        this.gameRepository = gameRepository;
        this.userGameRepository = userGameRepository;
        this.playLogRepository = playLogRepository;
        this.userRepository = userRepository;
        this.bggApiClient = bggApiClient;
        this.gameHydrationService = gameHydrationService;
        this.searchTranslationService = searchTranslationService;
        this.recommendationService = recommendationService;
        this.rulebookRepository = rulebookRepository;
        this.eventParticipantRepository = eventParticipantRepository;
    }

    // -------------------------------------------------------------------------
    // Recommendations
    // -------------------------------------------------------------------------

    public org.springframework.data.domain.Page<GameSummaryResponse> getRecommended(UUID userId,
            org.springframework.data.domain.Pageable pageable) {
        return recommendationService.getRecommended(userId, pageable);
    }

    // -------------------------------------------------------------------------
    // Browse - Local DB with dynamic filters
    // -------------------------------------------------------------------------

    public Page<GameSummaryResponse> browse(String query, String genre, Integer minPlayers, Integer maxPlayers,
            Integer minPlaytime, Integer maxPlaytime,
            java.math.BigDecimal minComplexity, java.math.BigDecimal maxComplexity,
            java.math.BigDecimal minRating, Pageable pageable) {
        // Sanitize Sort orders and resolve PostgreSQL NULLS FIRST defaults by filtering
        // out nulls
        java.util.List<Sort.Order> normalizedOrders = new java.util.ArrayList<>();
        java.util.List<String> sortedProperties = new java.util.ArrayList<>();
        if (pageable.getSort().isSorted()) {
            for (Sort.Order order : pageable.getSort()) {
                // 'recommended' is a virtual sort handled by the controller's personalized
                // endpoint.
                if ("recommended".equalsIgnoreCase(order.getProperty()))
                    continue;

                normalizedOrders.add(order);
                sortedProperties.add(order.getProperty());
            }
        }

        // Enforce stable sorting (tie-breaker) to prevent duplicates during background
        // heap updates
        if (normalizedOrders.stream().noneMatch(o -> "id".equalsIgnoreCase(o.getProperty()))) {
            normalizedOrders.add(Sort.Order.asc("id"));
        }

        pageable = PageRequest.of(pageable.getPageNumber(), pageable.getPageSize(), Sort.by(normalizedOrders));

        Specification<Game> spec = Specification.where(
                (root, cq, cb) -> {
                    Predicate p = cb.equal(root.get("gameType"), "boardgame");
                    // Filter out nulls for sorted fields to emulate nullsLast() since JPA lacks
                    // support
                    for (String prop : sortedProperties) {
                        if (!"id".equalsIgnoreCase(prop) && !"yearPublished".equalsIgnoreCase(prop)) {
                            p = cb.and(p, cb.isNotNull(root.get(prop)));
                        }
                    }
                    return p;
                });
        if (genre != null && !genre.isBlank()) {
            if ("2 Player".equalsIgnoreCase(genre)) {
                spec = spec.and((root, cq, cb) -> cb.and(
                        cb.le(root.get("minPlayers"), 2),
                        cb.ge(root.get("maxPlayers"), 2)));
            } else {
                spec = spec.and((root, cq, cb) -> {
                    Join<Game, GameDetail> join = root.join("gameDetail");
                    if ("Strategy".equalsIgnoreCase(genre)) {
                        return cb.or(cb.isNotNull(join.get("rankStrategy")),
                                cb.like(cb.function("array_to_string", String.class, join.get("families"),
                                        cb.literal(",")), "%Strategy Games%"));
                    } else if ("Party".equalsIgnoreCase(genre)) {
                        return cb.or(cb.isNotNull(join.get("rankParty")),
                                cb.like(cb.function("array_to_string", String.class, join.get("families"),
                                        cb.literal(",")), "%Party Games%"));
                    } else if ("Family".equalsIgnoreCase(genre)) {
                        return cb.or(cb.isNotNull(join.get("rankFamily")),
                                cb.like(cb.function("array_to_string", String.class, join.get("families"),
                                        cb.literal(",")), "%Family Games%"));
                    } else if ("Abstract".equalsIgnoreCase(genre)) {
                        return cb.or(cb.isNotNull(join.get("rankAbstract")),
                                cb.like(cb.function("array_to_string", String.class, join.get("families"),
                                        cb.literal(",")), "%Abstract Games%"));
                    }
                    return cb.conjunction();
                });
            }
        }

        if (query != null && !query.isBlank()) {
            String likeQ = "%" + query.toLowerCase() + "%";
            spec = spec.and((root, cq, cb) -> cb.or(
                    cb.like(cb.lower(root.get("nameEn")), likeQ),
                    cb.like(cb.lower(root.get("nameZh")), likeQ)));
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
    // Search — LIKE primary, CJK translation, trigram fallback for typos

    public List<GameSearchResult> search(String query) {
        if (query == null || query.isBlank())
            return List.of();

        // Step 1: translate CJK queries to English (only fires when CJK detected)
        SearchTranslationService.TranslationResult translation = searchTranslationService.translateIfNeeded(query);
        String effectiveQuery = translation.query();

        // Step 2: fast LIKE search (no AI cost)
        List<GameSearchResult> results = likeSearch(effectiveQuery, translation.translatedFrom());

        // Step 3: trigram fallback — only when LIKE found nothing (handles typos like
        // "cata" → Catan)
        if (results.isEmpty()) {
            results = gameRepository.searchTrigram(effectiveQuery)
                    .stream()
                    .map(p -> new GameSearchResult(
                            p.getId(), p.getBggId(), p.getNameEn(),
                            p.getYearPublished(), p.getThumbnailUrl(),
                            translation.translatedFrom()))
                    .toList();
        }

        return results;
    }

    private List<GameSearchResult> likeSearch(String query, String translatedFrom) {
        String likeQ = "%" + query.toLowerCase() + "%";
        Specification<Game> spec = Specification.<Game>where(
                (root, cq, cb) -> cb.or(
                        cb.like(cb.lower(root.get("nameEn")), likeQ),
                        cb.like(cb.lower(root.get("nameZh")), likeQ)))
                .and((root, cq, cb) -> cb.equal(root.get("gameType"), "boardgame"));

        return gameRepository.findAll(spec, org.springframework.data.domain.PageRequest.of(0, 20))
                .stream()
                .map(g -> new GameSearchResult(
                        g.getId(), g.getBggId(), g.getNameEn(),
                        g.getYearPublished(), g.getThumbnailUrl(),
                        translatedFrom))
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
        boolean hasRulebook = rulebookRepository.existsByGame_IdAndStatus(gameId, "approved");
        return GameDetailResponse.from(game, hasRulebook);
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
            case "owned" -> userGameRepository.findOwnedByUserId(userId);
            case "favorited" -> userGameRepository.findFavoritedByUserId(userId);
            default -> userGameRepository.findAllByUserId(userId);
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

        if (req.isOwned() != null)
            ug.setOwned(req.isOwned());
        if (req.isFavorited() != null)
            ug.setFavorited(req.isFavorited());
        if (req.personalRating() != null)
            ug.setPersonalRating(req.personalRating());
        if (req.notes() != null)
            ug.setNotes(req.notes());

        UserGameResponse saved = UserGameResponse.from(userGameRepository.save(ug));
        recommendationService.invalidateCache(userId);
        return saved;
    }

    @Transactional
    public UserGameResponse logPlay(UUID userId, UUID gameId) {
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

        ug.setPlayCount(ug.getPlayCount() + 1);
        userGameRepository.save(ug);

        PlayLog log = new PlayLog();
        log.setUser(user);
        log.setGame(game);
        playLogRepository.save(log);

        recommendationService.invalidateCache(userId);
        return UserGameResponse.from(ug);
    }

    public List<PlayLogResponse> getPlays(UUID userId, UUID gameId) {
        return playLogRepository.findByUserIdAndGameIdOrderByPlayedAtDesc(userId, gameId)
                .stream().map(PlayLogResponse::from).toList();
    }

    public List<ActivityLogResponse> getActivity(UUID userId) {
        List<ActivityLogResponse> items = new ArrayList<>();

        playLogRepository.findByUserIdOrderByPlayedAtDesc(userId, PageRequest.of(0, 50))
                .stream().map(ActivityLogResponse::fromPlay).forEach(items::add);

        eventParticipantRepository.findAcceptedByUserId(userId)
                .stream().map(ActivityLogResponse::fromEvent).forEach(items::add);

        items.sort(Comparator.comparing(ActivityLogResponse::playedAt).reversed());
        return items.stream().limit(50).toList();
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
