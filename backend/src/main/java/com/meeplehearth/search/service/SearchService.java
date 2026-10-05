package com.meeplehearth.search.service;

import com.meeplehearth.event.entity.Event;
import com.meeplehearth.game.dto.GameSummaryResponse;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.search.dto.SearchResponse;
import com.meeplehearth.search.dto.SearchResponse.EventSummary;
import com.meeplehearth.search.dto.SearchResponse.GameRef;
import com.meeplehearth.search.repository.EventSearchRepository;
import com.meeplehearth.social.dto.UserSummaryWithStatus;
import com.meeplehearth.social.service.SocialQueryService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Unified search for the search overlay (SCREENS_AND_STATES 13): games (fuzzy trigram match),
 * players (with friendship status, blocked users excluded) and events visible to the viewer.
 */
@Service
@Transactional(readOnly = true)
public class SearchService {

    public static final int DEFAULT_LIMIT = 3;
    static final int MAX_LIMIT = 20;
    static final int MAX_QUERY_LENGTH = 100;

    /** Which categories to search; {@link #ALL} unless the client narrows it. */
    public enum Scope { ALL, GAMES, USERS, EVENTS }

    private final GameRepository gameRepository;
    private final SocialQueryService socialQueryService;
    private final EventSearchRepository eventSearchRepository;

    public SearchService(GameRepository gameRepository,
                         SocialQueryService socialQueryService,
                         EventSearchRepository eventSearchRepository) {
        this.gameRepository = gameRepository;
        this.socialQueryService = socialQueryService;
        this.eventSearchRepository = eventSearchRepository;
    }

    public SearchResponse search(UUID viewerId, String q, int limit, Scope scope) {
        String term = q == null ? "" : q.trim();
        if (term.isEmpty()) {
            return SearchResponse.empty();
        }
        if (term.length() > MAX_QUERY_LENGTH) {
            term = term.substring(0, MAX_QUERY_LENGTH);
        }
        int safeLimit = Math.clamp(limit, 1, MAX_LIMIT);
        boolean all = scope == null || scope == Scope.ALL;

        List<GameSummaryResponse> games = all || scope == Scope.GAMES ? games(term, safeLimit) : List.of();
        List<UserSummaryWithStatus> users = all || scope == Scope.USERS
                ? socialQueryService.searchWithStatus(viewerId, term, safeLimit) : List.of();
        List<EventSummary> events = all || scope == Scope.EVENTS ? events(viewerId, term, safeLimit) : List.of();
        return new SearchResponse(games, users, events);
    }

    private List<GameSummaryResponse> games(String term, int limit) {
        List<UUID> ids = gameRepository.searchTrigram(term).stream()
                .limit(limit)
                .map(GameRepository.GameSearchProjection::getId)
                .toList();
        if (ids.isEmpty()) {
            return List.of();
        }
        Map<UUID, Game> byId = gameRepository.findAllById(ids).stream()
                .collect(Collectors.toMap(Game::getId, Function.identity()));
        return ids.stream().map(byId::get).filter(Objects::nonNull).map(GameSummaryResponse::from).toList();
    }

    private List<EventSummary> events(UUID viewerId, String term, int limit) {
        String pattern = "%" + SocialQueryService.escapeLike(term.toLowerCase(Locale.ROOT)) + "%";
        return eventSearchRepository.search(viewerId, pattern, limit).stream()
                .map(SearchService::toSummary)
                .toList();
    }

    private static EventSummary toSummary(Event e) {
        GameRef game = e.getGame() == null ? null
                : new GameRef(e.getGame().getId(), e.getGame().getNameEn(), e.getGame().getThumbnailUrl());
        return new EventSummary(e.getId(), e.getTitle(), e.getScheduledAt(), e.getStatus().name(),
                e.getVisibility().name(), game);
    }
}
