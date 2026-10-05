package com.meeplehearth.feed.service;

import com.meeplehearth.event.entity.Event;
import com.meeplehearth.feed.dto.ActivityResponse;
import com.meeplehearth.feed.dto.CursorPage;
import com.meeplehearth.feed.dto.FeedItem;
import com.meeplehearth.feed.entity.ActivityEvent;
import com.meeplehearth.feed.repository.ActivityEventRepository;
import com.meeplehearth.feed.repository.FeedQueryRepository;
import com.meeplehearth.feed.service.FeedCache.FeedRef;
import com.meeplehearth.feed.service.FeedCache.Skeleton;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.post.dto.PostResponse;
import com.meeplehearth.post.service.PostService;
import com.meeplehearth.user.dto.UserSummary;
import com.meeplehearth.social.repository.BlockRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Home feed (FEATURES_COMPLETE 5.1, 5.5): the viewer's and their friends' posts and activity
 * items, strictly reverse-chronological, keyset-paged. Page skeletons are cached for 60s in
 * {@link FeedCache}; items are hydrated per request so viewer-specific state is never stale.
 */
@Service
public class FeedService {

    public static final int DEFAULT_LIMIT = 20;
    static final int MAX_LIMIT = 50;

    private final FeedQueryRepository feedQueryRepository;
    private final ActivityEventRepository activityEventRepository;
    private final GameRepository gameRepository;
    private final BlockRepository blockRepository;
    private final PostService postService;
    private final FeedCache feedCache;

    public FeedService(FeedQueryRepository feedQueryRepository,
                       ActivityEventRepository activityEventRepository,
                       GameRepository gameRepository,
                       BlockRepository blockRepository,
                       PostService postService,
                       FeedCache feedCache) {
        this.feedQueryRepository = feedQueryRepository;
        this.activityEventRepository = activityEventRepository;
        this.gameRepository = gameRepository;
        this.blockRepository = blockRepository;
        this.postService = postService;
        this.feedCache = feedCache;
    }

    @Transactional(readOnly = true)
    public CursorPage<FeedItem> getFeed(UUID viewerId, String cursor, int limit) {
        FeedCursor parsed = FeedCursor.parse(cursor); // validate before touching the cache
        int safeLimit = Math.clamp(limit, 1, MAX_LIMIT);
        String cacheCursor = parsed == null ? null : cursor.trim();

        Skeleton skeleton = feedCache.get(viewerId, cacheCursor)
                .filter(s -> s.limit() == safeLimit)
                .orElseGet(() -> {
                    Skeleton fresh = loadSkeleton(viewerId, parsed, safeLimit);
                    feedCache.put(viewerId, cacheCursor, fresh);
                    return fresh;
                });
        return new CursorPage<>(hydrate(skeleton.refs(), viewerId), skeleton.nextCursor(), skeleton.hasMore());
    }

    private Skeleton loadSkeleton(UUID viewerId, FeedCursor cursor, int limit) {
        List<FeedRef> rows = feedQueryRepository.findPage(viewerId, cursor, limit + 1);
        boolean hasMore = rows.size() > limit;
        List<FeedRef> page = hasMore ? List.copyOf(rows.subList(0, limit)) : rows;
        String next = null;
        if (hasMore) {
            FeedRef last = page.get(page.size() - 1);
            next = FeedCursor.encode(last.createdAt(), last.id());
        }
        return new Skeleton(limit, page, next, hasMore);
    }

    private List<FeedItem> hydrate(List<FeedRef> refs, UUID viewerId) {
        List<UUID> postIds = new ArrayList<>();
        List<UUID> activityIds = new ArrayList<>();
        for (FeedRef ref : refs) {
            (FeedItem.POST.equals(ref.kind()) ? postIds : activityIds).add(ref.id());
        }
        Map<UUID, PostResponse> posts = postService.loadVisible(postIds, viewerId);
        Map<UUID, ActivityResponse> activities = loadActivities(activityIds, viewerId);

        List<FeedItem> items = new ArrayList<>(refs.size());
        for (FeedRef ref : refs) {
            if (FeedItem.POST.equals(ref.kind())) {
                Optional.ofNullable(posts.get(ref.id())).map(FeedItem::post).ifPresent(items::add);
            } else {
                Optional.ofNullable(activities.get(ref.id()))
                        .map(a -> FeedItem.activity(ref.createdAt(), a))
                        .ifPresent(items::add);
            }
        }
        return items;
    }

    /**
     * Loads activities with their user, game and event in a fixed number of queries. An activity
     * whose event the viewer can no longer see (deleted, cancelled, visibility) or whose game is
     * gone is dropped; so are activities of users blocked either way.
     */
    private Map<UUID, ActivityResponse> loadActivities(List<UUID> ids, UUID viewerId) {
        if (ids.isEmpty()) {
            return Map.of();
        }
        Set<UUID> hidden = blockRepository.findBlockedEitherWay(viewerId);
        List<ActivityEvent> rows = activityEventRepository.findActiveWithUserByIdIn(ids).stream()
                .filter(a -> a.getUser().getDeletedAt() == null && !hidden.contains(a.getUser().getId()))
                .toList();

        Set<UUID> gameIds = new HashSet<>();
        Set<UUID> eventIds = new HashSet<>();
        for (ActivityEvent a : rows) {
            uuid(a.getData().get("gameId")).ifPresent(gameIds::add);
            uuid(a.getData().get("eventId")).ifPresent(eventIds::add);
        }
        Map<UUID, Game> games = gameIds.isEmpty() ? Map.of() : gameRepository.findAllById(gameIds).stream()
                .collect(Collectors.toMap(Game::getId, Function.identity()));
        Map<UUID, Event> events = feedQueryRepository.findVisibleEvents(eventIds, viewerId).stream()
                .collect(Collectors.toMap(Event::getId, Function.identity()));

        Map<UUID, ActivityResponse> result = new LinkedHashMap<>();
        for (ActivityEvent a : rows) {
            enrich(a, games, events).ifPresent(data ->
                    result.put(a.getId(), new ActivityResponse(a.getId(), a.getType(), UserSummary.from(a.getUser()), data)));
        }
        return result;
    }

    /**
     * Adds current display fields to an activity's payload. Empty when the activity's subject is
     * gone or hidden: an event activity needs a visible event, a collection activity a game.
     */
    private static Optional<Map<String, Object>> enrich(ActivityEvent a, Map<UUID, Game> games, Map<UUID, Event> events) {
        Map<String, Object> data = new LinkedHashMap<>(a.getData());
        Game game = uuid(a.getData().get("gameId")).map(games::get).orElse(null);
        if (a.getType().startsWith("event_")) {
            Event event = uuid(a.getData().get("eventId")).map(events::get).orElse(null);
            if (event == null) {
                return Optional.empty();
            }
            data.put("eventTitle", event.getTitle());
            data.put("eventScheduledAt", event.getScheduledAt().toString());
            if (game == null && event.getGame() != null) {
                game = event.getGame();
                data.put("gameId", game.getId().toString());
            }
        } else if (game == null) {
            return Optional.empty();
        }
        if (game != null) {
            data.put("gameName", game.getNameEn());
            data.put("gameThumbnailUrl", game.getThumbnailUrl());
        }
        return Optional.of(data);
    }

    /** Payload ids may arrive as UUID or String depending on the publisher. */
    static Optional<UUID> uuid(Object value) {
        if (value instanceof UUID id) {
            return Optional.of(id);
        }
        if (value instanceof String s) {
            try {
                return Optional.of(UUID.fromString(s));
            } catch (IllegalArgumentException e) {
                return Optional.empty();
            }
        }
        return Optional.empty();
    }
}
