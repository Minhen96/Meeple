package com.meeplehearth.game.service;

import com.meeplehearth.ai.repository.GameRulebookRepository;
import com.meeplehearth.common.event.ActivityRecordedEvent;
import com.meeplehearth.config.CacheConfig.CacheNames;
import com.meeplehearth.event.entity.Event;
import com.meeplehearth.event.entity.EventParticipant;
import com.meeplehearth.ai.service.SearchTranslationService;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.game.client.BggApiClient;
import com.meeplehearth.game.dto.*;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.entity.GameDetail;
import com.meeplehearth.game.entity.UserGame;
import com.meeplehearth.event.repository.EventParticipantRepository;
import com.meeplehearth.game.repository.GameDetailRepository;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.game.repository.PlayLogRepository;
import com.meeplehearth.game.repository.UserGameRepository;
import com.meeplehearth.post.repository.PostRepository;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import jakarta.persistence.criteria.CriteriaBuilder;
import jakarta.persistence.criteria.CriteriaQuery;
import jakarta.persistence.criteria.Predicate;
import jakarta.persistence.criteria.Root;
import jakarta.persistence.criteria.Subquery;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
public class GameService {

    private final GameRepository gameRepository;
    private final GameDetailRepository gameDetailRepository;
    private final UserGameRepository userGameRepository;
    private final PlayLogRepository playLogRepository;
    private final UserRepository userRepository;
    private final BggApiClient bggApiClient;
    private final GameHydrationService gameHydrationService;
    private final SearchTranslationService searchTranslationService;
    private final RecommendationService recommendationService;
    private final GameRulebookRepository rulebookRepository;
    private final EventParticipantRepository eventParticipantRepository;
    private final PostRepository postRepository;
    private final TransactionTemplate transactionTemplate;
    private final UserCollectionReader collectionReader;
    private final GameCacheEvictor cacheEvictor;
    private final ApplicationEventPublisher eventPublisher;

    public GameService(GameRepository gameRepository,
            GameDetailRepository gameDetailRepository,
            UserGameRepository userGameRepository,
            PlayLogRepository playLogRepository,
            UserRepository userRepository,
            BggApiClient bggApiClient,
            GameHydrationService gameHydrationService,
            SearchTranslationService searchTranslationService,
            RecommendationService recommendationService,
            GameRulebookRepository rulebookRepository,
            EventParticipantRepository eventParticipantRepository,
            PostRepository postRepository,
            PlatformTransactionManager transactionManager,
            UserCollectionReader collectionReader,
            GameCacheEvictor cacheEvictor,
            ApplicationEventPublisher eventPublisher) {
        this.gameRepository = gameRepository;
        this.gameDetailRepository = gameDetailRepository;
        this.transactionTemplate = new TransactionTemplate(transactionManager);
        this.userGameRepository = userGameRepository;
        this.playLogRepository = playLogRepository;
        this.userRepository = userRepository;
        this.bggApiClient = bggApiClient;
        this.gameHydrationService = gameHydrationService;
        this.searchTranslationService = searchTranslationService;
        this.recommendationService = recommendationService;
        this.rulebookRepository = rulebookRepository;
        this.eventParticipantRepository = eventParticipantRepository;
        this.postRepository = postRepository;
        this.collectionReader = collectionReader;
        this.cacheEvictor = cacheEvictor;
        this.eventPublisher = eventPublisher;
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
                    String rankField;
                    String familyPattern;
                    if ("Strategy".equalsIgnoreCase(genre)) {
                        rankField = "rankStrategy";
                        familyPattern = "%Strategy Games%";
                    } else if ("Party".equalsIgnoreCase(genre)) {
                        rankField = "rankParty";
                        familyPattern = "%Party Games%";
                    } else if ("Family".equalsIgnoreCase(genre)) {
                        rankField = "rankFamily";
                        familyPattern = "%Family Games%";
                    } else if ("Abstract".equalsIgnoreCase(genre)) {
                        rankField = "rankAbstract";
                        familyPattern = "%Abstract Games%";
                    } else {
                        // Unknown genre: previous behaviour still required a game_details row
                        return detailExists(root, cq, cb, d -> cb.conjunction());
                    }
                    return detailExists(root, cq, cb, d -> cb.or(cb.isNotNull(d.get(rankField)),
                            cb.like(cb.function("array_to_string", String.class, d.get("families"),
                                    cb.literal(",")), familyPattern)));
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
            spec = spec.and((root, cq, cb) -> detailExists(root, cq, cb, d -> {
                if (minComplexity != null && maxComplexity != null) {
                    return cb.between(d.get("complexity"), minComplexity, maxComplexity);
                } else if (minComplexity != null) {
                    return cb.ge(d.get("complexity"), minComplexity);
                } else {
                    return cb.le(d.get("complexity"), maxComplexity);
                }
            }));
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
        // Use cq.orderBy() directly so we can express NULLS LAST via a CASE expression.
        // Sort.Order.nullsLast() is not reliably supported by JPA/Hibernate on all versions.
        Specification<Game> spec = (root, cq, cb) -> {
            if (!Long.class.equals(cq.getResultType())) {
                cq.orderBy(
                    cb.asc(cb.selectCase()
                        .when(cb.isNull(root.get("rank")), 1)
                        .otherwise(0)),
                    cb.asc(root.get("rank")),
                    cb.desc(cb.coalesce(root.<Integer>get("usersRated"), 0))
                );
            }
            return cb.and(
                cb.or(
                    cb.like(cb.lower(root.get("nameEn")), likeQ),
                    cb.like(cb.lower(root.get("nameZh")), likeQ)
                ),
                cb.equal(root.get("gameType"), "boardgame")
            );
        };

        return gameRepository.findAll(spec, PageRequest.of(0, 20))
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

    /**
     * Viewer-independent game detail, cached for 7 days in "game-detail" (evicted when a rulebook
     * is approved). Not cached while the game is still unhydrated, so the next request retries
     * hydration. Friend data is added per viewer by {@link GameSocialService#withFriendData}.
     *
     * <p>Not @Transactional on purpose: the optional synchronous BGG hydration must not run
     * inside a DB transaction. Hydration persists in its own short transaction, after
     * which the game is re-read.
     */
    @Cacheable(cacheNames = CacheNames.GAME_DETAIL, key = "#gameId", unless = "#result.minPlayers() == null")
    public GameDetailResponse getGame(UUID gameId) {
        Game game = gameRepository.findById(gameId)
                .orElseThrow(() -> ApiException.notFound("GAME_NOT_FOUND", "Game not found"));
        if (game.getMinPlayers() == null && gameHydrationService.hydrateImageSync(game)) {
            game = gameRepository.findById(gameId).orElse(game);
        }
        GameDetail detail = gameDetailRepository.findById(gameId).orElse(null);
        boolean hasRulebook = rulebookRepository.existsByGame_IdAndStatus(gameId, "approved");
        return GameDetailResponse.from(game, detail, hasRulebook);
    }

    /** The BGG lookup runs outside any transaction; only the insert is transactional. */
    public GameDetailResponse ensureGame(Long bggId) {
        var existing = gameRepository.findByBggId(bggId);
        if (existing.isPresent()) {
            Game game = existing.get();
            return GameDetailResponse.from(game, gameDetailRepository.findById(game.getId()).orElse(null));
        }

        BggApiClient.BggGameDetail detail;
        try {
            detail = bggApiClient.getDetail(bggId)
                    .orElseThrow(() -> ApiException.notFound("GAME_NOT_FOUND", "Game not found on BGG"));
        } catch (BggApiClient.BggUnavailableException e) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "BGG_UNAVAILABLE",
                    "Board game data source is temporarily unavailable. Try again later.");
        }

        try {
            return transactionTemplate.execute(status -> {
                Game game = gameRepository.save(mapToEntity(detail));
                GameDetail gDetail = gameDetailRepository.save(mapToDetail(detail, game));
                return GameDetailResponse.from(game, gDetail);
            });
        } catch (DataIntegrityViolationException e) {
            // A concurrent request inserted the same bgg_id first — return that row
            Game game = gameRepository.findByBggId(bggId).orElseThrow(() -> e);
            return GameDetailResponse.from(game, gameDetailRepository.findById(game.getId()).orElse(null));
        }
    }

    /** EXISTS (SELECT d.id FROM GameDetail d WHERE d.id = game.id AND condition(d)). */
    private static Predicate detailExists(Root<Game> root, CriteriaQuery<?> cq, CriteriaBuilder cb,
            Function<Root<GameDetail>, Predicate> condition) {
        Subquery<UUID> sq = cq.subquery(UUID.class);
        Root<GameDetail> d = sq.from(GameDetail.class);
        sq.select(d.get("id")).where(cb.equal(d.get("id"), root.get("id")), condition.apply(d));
        return cb.exists(sq);
    }

    // -------------------------------------------------------------------------
    // Collection
    // -------------------------------------------------------------------------

    /** Collection filters accepted by {@code GET /users/{id}/games?filter=}. */
    public static final List<String> COLLECTION_FILTERS = List.of("all", "owned", "wishlisted", "favorited");

    /**
     * The user's collection entries for {@code filter} (all | owned | wishlisted | favorited), read
     * from the cached full collection.
     */
    public List<UserGameResponse> getCollection(UUID userId, String filter) {
        String f = filter == null ? "all" : filter.toLowerCase(Locale.ROOT);
        if (!COLLECTION_FILTERS.contains(f)) {
            throw ApiException.badRequest("INVALID_FILTER", "filter must be one of " + COLLECTION_FILTERS);
        }
        List<UserGameResponse> all = collectionReader.load(userId);
        return switch (f) {
            case "owned" -> all.stream().filter(UserGameResponse::isOwned).toList();
            case "wishlisted" -> all.stream().filter(UserGameResponse::isWishlisted).toList();
            case "favorited" -> all.stream().filter(UserGameResponse::isFavorited).toList();
            default -> all;
        };
    }

    /**
     * Upserts the caller's entry for a game. An update that leaves every flag false and nothing
     * else on the entry deletes it (FEATURES_COMPLETE section 3.1) and returns
     * {@link UserGameResponse#removed}. Marking a game owned publishes a {@code collection_add}
     * activity for the feed.
     */
    @Transactional
    public UserGameResponse updateCollection(UUID userId, UUID gameId, UserGameRequest req) {
        BigDecimal rating = req.personalRating();
        if (rating != null && rating.signum() > 0 && rating.compareTo(BigDecimal.ONE) < 0) {
            throw ApiException.badRequest("INVALID_RATING", "Rating must be between 1 and 10, or 0 to clear it");
        }
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
        boolean wasOwned = ug.isOwned();

        if (req.isOwned() != null)
            ug.setOwned(req.isOwned());
        if (req.isWishlisted() != null)
            ug.setWishlisted(req.isWishlisted());
        if (req.isFavorited() != null)
            ug.setFavorited(req.isFavorited());
        if (rating != null)
            ug.setPersonalRating(rating.signum() == 0 ? null : rating);
        if (req.notes() != null)
            ug.setNotes(req.notes().isBlank() ? null : req.notes());

        cacheEvictor.evictCollection(userId);
        recommendationService.invalidateCache(userId);

        if (ug.isEmpty()) {
            if (ug.getId() != null) {
                userGameRepository.delete(ug);
            }
            return UserGameResponse.removed(ug);
        }

        UserGame saved = userGameRepository.save(ug);
        if (!wasOwned && saved.isOwned()) {
            Map<String, Object> data = new LinkedHashMap<>();
            data.put("gameId", game.getId().toString());
            data.put("gameTitle", game.getNameEn());
            data.put("thumbnailUrl", game.getThumbnailUrl());
            eventPublisher.publishEvent(new ActivityRecordedEvent(
                    userId, ActivityRecordedEvent.COLLECTION_ADD, data, Instant.now()));
        }
        return UserGameResponse.from(saved);
    }

    /**
     * Recent activity of {@code userId} (plays, accepted events, posts), newest first, at most 50.
     * Another viewer only sees public events, and their full address only when they host or
     * joined the event themselves (the {@code EventResponse} rule); otherwise the public
     * area/venue ({@code locationDisplay}).
     */
    @Transactional(readOnly = true)
    public List<ActivityLogResponse> getActivity(UUID userId, UUID viewerId) {
        boolean self = userId.equals(viewerId);
        List<ActivityLogResponse> items = new ArrayList<>();

        // 1. Plays
        playLogRepository.findByUserIdOrderByPlayedAtDesc(userId, PageRequest.of(0, 50))
                .stream().map(ActivityLogResponse::fromPlay).forEach(items::add);

        // 2. Events (accepted only, not deleted; public only for other viewers)
        List<EventParticipant> attended = eventParticipantRepository.findAcceptedByUserId(userId)
                .stream()
                .filter(ep -> ep.getEvent().getDeletedAt() == null)
                .filter(ep -> self || ep.getEvent().getVisibility() == Event.Visibility.PUBLIC)
                .toList();
        Set<UUID> viewerJoined = self || attended.isEmpty() ? Set.of()
                : eventParticipantRepository.findByUserIdAndEventIds(viewerId,
                                attended.stream().map(ep -> ep.getId().getEventId()).toList()).stream()
                        .filter(vp -> vp.getStatus() == EventParticipant.RsvpStatus.ACCEPTED)
                        .map(vp -> vp.getId().getEventId())
                        .collect(Collectors.toSet());
        for (EventParticipant ep : attended) {
            Event event = ep.getEvent();
            boolean full = self || viewerId.equals(event.hostIdOrNull())
                    || viewerJoined.contains(ep.getId().getEventId());
            items.add(ActivityLogResponse.fromEvent(ep, full ? event.getLocation() : event.getLocationDisplay()));
        }

        // 3. Posts
        postRepository.findByAuthorId(userId, PageRequest.of(0, 50))
                .stream().map(ActivityLogResponse::fromPost).forEach(items::add);

        // Sort unified timeline (newest first)
        items.sort(Comparator.comparing(ActivityLogResponse::playedAt,
                Comparator.nullsLast(Comparator.<Instant>naturalOrder())).reversed());

        return items.stream().limit(50).toList();
    }

    @Transactional
    public void removeFromCollection(UUID userId, UUID gameId) {
        UserGame ug = userGameRepository.findByUserIdAndGameId(userId, gameId)
                .orElseThrow(() -> ApiException.notFound("COLLECTION_ENTRY_NOT_FOUND", "Game not in collection"));
        userGameRepository.delete(ug);
        cacheEvictor.evictCollection(userId);
        recommendationService.invalidateCache(userId);
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
        return game;
    }

    private GameDetail mapToDetail(BggApiClient.BggGameDetail detail, Game game) {
        GameDetail gDetail = new GameDetail();
        gDetail.setGame(game);
        gDetail.setDescription(detail.description());
        gDetail.setComplexity(detail.complexityWeight());
        return gDetail;
    }
}
