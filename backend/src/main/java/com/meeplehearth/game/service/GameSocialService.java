package com.meeplehearth.game.service;

import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.game.dto.CursorPage;
import com.meeplehearth.game.dto.GameDetailResponse;
import com.meeplehearth.game.dto.GameFriendResponse;
import com.meeplehearth.game.dto.GameReviewResponse;
import com.meeplehearth.game.dto.UserSummary;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.game.repository.LibraryStatsQueries;
import com.meeplehearth.game.repository.LibraryStatsQueries.PostKey;
import com.meeplehearth.game.repository.UserGameRepository;
import com.meeplehearth.post.dto.PostResponse;
import com.meeplehearth.post.entity.Post;
import com.meeplehearth.post.entity.PostLikeId;
import com.meeplehearth.post.repository.PostLikeRepository;
import com.meeplehearth.social.repository.BlockRepository;
import com.meeplehearth.post.repository.PostRepository;
import com.meeplehearth.social.repository.FriendRequestRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Friend-related game detail data (SCREENS_AND_STATES section 5.4): friends who own a game,
 * friends' reviews, the friend average rating and the sessions (posts) logged with the game.
 * "Friends" are accepted friend requests (CLAUDE.md friend model); a block removes the
 * friendship, and sessions additionally exclude authors blocked with the viewer.
 */
@Service
public class GameSocialService {

    /** Avatars shown in the "Owned by X friends" stack. */
    static final int OWNED_BY_FRIENDS_PREVIEW = 5;
    static final int DEFAULT_LIMIT = 20;
    static final int MAX_LIMIT = 100;

    private final GameRepository gameRepository;
    private final UserGameRepository userGameRepository;
    private final FriendRequestRepository friendRequestRepository;
    private final LibraryStatsQueries queries;
    private final PostRepository postRepository;
    private final PostLikeRepository postLikeRepository;
    private final BlockRepository blockRepository;

    public GameSocialService(GameRepository gameRepository,
                             UserGameRepository userGameRepository,
                             FriendRequestRepository friendRequestRepository,
                             LibraryStatsQueries queries,
                             PostRepository postRepository,
                             PostLikeRepository postLikeRepository,
                             BlockRepository blockRepository) {
        this.gameRepository = gameRepository;
        this.userGameRepository = userGameRepository;
        this.friendRequestRepository = friendRequestRepository;
        this.queries = queries;
        this.postRepository = postRepository;
        this.postLikeRepository = postLikeRepository;
        this.blockRepository = blockRepository;
    }

    /** Adds the viewer's friend average rating and up to 5 friends who own the game. */
    @Transactional(readOnly = true)
    public GameDetailResponse withFriendData(GameDetailResponse detail, UUID viewerId) {
        List<UUID> friendIds = friendIds(viewerId);
        if (friendIds.isEmpty()) {
            return detail.withFriendData(null, 0, List.of());
        }
        BigDecimal average = null;
        int count = 0;
        List<Object[]> aggregate = userGameRepository.ratingAggregateAmong(detail.id(), friendIds);
        if (!aggregate.isEmpty() && aggregate.get(0)[0] != null) {
            Object[] row = aggregate.get(0);
            average = toBigDecimal(row[0]).setScale(1, RoundingMode.HALF_UP);
            count = ((Number) row[1]).intValue();
        }
        List<UserSummary> owners = userGameRepository
                .findOwnersAmong(detail.id(), friendIds, PageRequest.of(0, OWNED_BY_FRIENDS_PREVIEW))
                .stream().map(ug -> UserSummary.from(ug.getUser())).toList();
        return detail.withFriendData(average, count, owners);
    }

    /** Friends who own the game, most played first. */
    @Transactional(readOnly = true)
    public List<GameFriendResponse> friendsWhoOwn(UUID gameId, UUID viewerId, Integer limit) {
        requireGame(gameId);
        List<UUID> friendIds = friendIds(viewerId);
        if (friendIds.isEmpty()) return List.of();
        return userGameRepository.findOwnersAmong(gameId, friendIds, PageRequest.of(0, clamp(limit))).stream()
                .map(ug -> new GameFriendResponse(UserSummary.from(ug.getUser()), ug.getPlayCount(),
                        ug.getPersonalRating(), ug.isOwned()))
                .toList();
    }

    /** Friends' ratings and notes for the game, most recently updated first. */
    @Transactional(readOnly = true)
    public List<GameReviewResponse> friendReviews(UUID gameId, UUID viewerId, Integer limit) {
        requireGame(gameId);
        List<UUID> friendIds = friendIds(viewerId);
        if (friendIds.isEmpty()) return List.of();
        return userGameRepository.findReviewsAmong(gameId, friendIds, PageRequest.of(0, clamp(limit))).stream()
                .map(ug -> new GameReviewResponse(UserSummary.from(ug.getUser()), ug.getPersonalRating(),
                        ug.getNotes(), ug.getPlayCount()))
                .toList();
    }

    /**
     * Posts with this game by the viewer and their friends, newest first. The cursor is opaque
     * ({@code {createdAt ISO}|{postId}}).
     *
     * @throws ApiException 400 INVALID_CURSOR for a malformed cursor, 404 GAME_NOT_FOUND
     */
    @Transactional(readOnly = true)
    public CursorPage<PostResponse> sessions(UUID gameId, UUID viewerId, String cursor, Integer limit) {
        requireGame(gameId);
        int size = clamp(limit);
        Instant cursorAt = null;
        UUID cursorId = null;
        if (cursor != null && !cursor.isBlank()) {
            int bar = cursor.lastIndexOf('|');
            try {
                if (bar < 0) {
                    cursorAt = Instant.parse(cursor.trim());
                    cursorId = new UUID(0L, 0L); // plain timestamp: strictly older posts only
                } else {
                    cursorAt = Instant.parse(cursor.substring(0, bar));
                    cursorId = UUID.fromString(cursor.substring(bar + 1));
                }
            } catch (DateTimeParseException | IllegalArgumentException e) {
                throw ApiException.badRequest("INVALID_CURSOR", "Invalid cursor");
            }
        }

        Set<UUID> authorIds = new LinkedHashSet<>(friendIds(viewerId));
        authorIds.add(viewerId);
        List<PostKey> keys = queries.sessionPostKeys(gameId, authorIds, viewerId, cursorAt, cursorId, size + 1);
        boolean hasMore = keys.size() > size;
        List<PostKey> page = hasMore ? keys.subList(0, size) : keys;
        if (page.isEmpty()) {
            return new CursorPage<>(List.of(), null, false);
        }

        List<UUID> ids = page.stream().map(PostKey::id).toList();
        Map<UUID, Post> byId = postRepository.findWithDetailsByIdIn(ids).stream()
                .collect(Collectors.toMap(Post::getId, Function.identity(), (a, b) -> a));
        postRepository.fetchTagsByIdIn(ids);
        Set<UUID> liked = postLikeRepository.findLikedPostIds(new HashSet<>(ids), viewerId).stream()
                .map(PostLikeId::getPostId).collect(Collectors.toSet());
        Set<UUID> hidden = blockRepository.findBlockedEitherWay(viewerId);

        List<PostResponse> items = new ArrayList<>(ids.size());
        for (UUID id : ids) {
            Post post = byId.get(id);
            if (post != null) items.add(PostResponse.from(post, liked.contains(id), hidden));
        }
        PostKey last = page.get(page.size() - 1);
        String next = hasMore ? last.createdAt().toString() + "|" + last.id() : null;
        return new CursorPage<>(items, next, hasMore);
    }

    private List<UUID> friendIds(UUID viewerId) {
        return friendRequestRepository.findFriendIds(viewerId).stream()
                .filter(Objects::nonNull).distinct().toList();
    }

    private void requireGame(UUID gameId) {
        if (!gameRepository.existsById(gameId)) {
            throw ApiException.notFound("GAME_NOT_FOUND", "Game not found");
        }
    }

    static int clamp(Integer limit) {
        if (limit == null || limit < 1) return DEFAULT_LIMIT;
        return Math.min(limit, MAX_LIMIT);
    }

    private static BigDecimal toBigDecimal(Object value) {
        return value instanceof BigDecimal bd ? bd : BigDecimal.valueOf(((Number) value).doubleValue());
    }
}
