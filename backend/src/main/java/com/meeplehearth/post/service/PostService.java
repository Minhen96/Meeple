package com.meeplehearth.post.service;

import com.meeplehearth.common.dto.PageMeta;
import com.meeplehearth.common.dto.PageResponse;
import com.meeplehearth.common.event.SessionPlayedEvent;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.config.AppProperties;
import com.meeplehearth.event.entity.Event;
import com.meeplehearth.event.entity.EventParticipant;
import com.meeplehearth.event.repository.EventParticipantRepository;
import com.meeplehearth.event.repository.EventRepository;
import com.meeplehearth.feed.dto.CursorPage;
import com.meeplehearth.feed.service.FeedCache;
import com.meeplehearth.feed.service.FeedCursor;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.notification.entity.Notification;
import com.meeplehearth.notification.service.NotificationService;
import com.meeplehearth.post.dto.CreateCommentRequest;
import com.meeplehearth.post.dto.CreatePostRequest;
import com.meeplehearth.post.dto.PostCommentResponse;
import com.meeplehearth.post.dto.PostResponse;
import com.meeplehearth.post.dto.UpdatePostRequest;
import com.meeplehearth.post.entity.Post;
import com.meeplehearth.post.entity.PostComment;
import com.meeplehearth.post.entity.PostImage;
import com.meeplehearth.post.entity.PostLikeId;
import com.meeplehearth.post.entity.PostTag;
import com.meeplehearth.post.repository.PostCommentRepository;
import com.meeplehearth.post.repository.PostLikeRepository;
import com.meeplehearth.post.repository.PostQueryRepository;
import com.meeplehearth.post.repository.PostRepository;
import com.meeplehearth.social.repository.BlockRepository;
import com.meeplehearth.social.repository.FriendRequestRepository;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
public class PostService {

    /** Posts can be edited for this long after creation (FEATURES_COMPLETE 5.4). */
    static final Duration POST_EDIT_WINDOW = Duration.ofHours(48);
    /** Comments can be edited for this long after creation (FEATURES_COMPLETE 5.7). */
    static final Duration COMMENT_EDIT_WINDOW = Duration.ofHours(24);
    /** Clock-skew allowance for "playedAt cannot be in the future". */
    static final Duration PLAYED_AT_SKEW = Duration.ofMinutes(5);
    static final int MAX_PAGE_SIZE = 50;

    private final PostRepository postRepository;
    private final PostLikeRepository postLikeRepository;
    private final PostCommentRepository postCommentRepository;
    private final PostQueryRepository postQueryRepository;
    private final UserRepository userRepository;
    private final GameRepository gameRepository;
    private final EventRepository eventRepository;
    private final EventParticipantRepository eventParticipantRepository;
    private final AppProperties appProperties;
    private final FriendRequestRepository friendRequestRepository;
    private final NotificationService notificationService;
    private final BlockRepository blockRepository;
    private final ApplicationEventPublisher eventPublisher;
    private final FeedCache feedCache;

    public PostService(PostRepository postRepository,
            PostLikeRepository postLikeRepository,
            PostCommentRepository postCommentRepository,
            PostQueryRepository postQueryRepository,
            UserRepository userRepository,
            GameRepository gameRepository,
            EventRepository eventRepository,
            EventParticipantRepository eventParticipantRepository,
            AppProperties appProperties,
            FriendRequestRepository friendRequestRepository,
            NotificationService notificationService,
            BlockRepository blockRepository,
            ApplicationEventPublisher eventPublisher,
            FeedCache feedCache) {
        this.postRepository = postRepository;
        this.postLikeRepository = postLikeRepository;
        this.postCommentRepository = postCommentRepository;
        this.postQueryRepository = postQueryRepository;
        this.userRepository = userRepository;
        this.gameRepository = gameRepository;
        this.eventRepository = eventRepository;
        this.eventParticipantRepository = eventParticipantRepository;
        this.appProperties = appProperties;
        this.friendRequestRepository = friendRequestRepository;
        this.notificationService = notificationService;
        this.blockRepository = blockRepository;
        this.eventPublisher = eventPublisher;
        this.feedCache = feedCache;
    }

    // -------------------------------------------------------------------------
    // Lists
    // -------------------------------------------------------------------------

    /**
     * Legacy offset feed of posts only ({@code GET /feed?page=}), kept one release for older
     * mobile builds. New clients use the cursor feed in the feed package.
     */
    @Transactional(readOnly = true)
    public PageResponse<PostResponse> getFeed(UUID currentUserId, int page, int size) {
        List<UUID> friendIds = friendRequestRepository.findFriendIds(currentUserId);
        List<UUID> feedIds = new ArrayList<>(friendIds);
        feedIds.add(currentUserId);
        Page<UUID> ids = postRepository.findFeedPostIds(feedIds, currentUserId,
                PageRequest.of(Math.max(page, 0), clampSize(size)));
        return toPageResponse(ids, currentUserId);
    }

    @Transactional(readOnly = true)
    public PageResponse<PostResponse> getUserPosts(UUID authorId, UUID currentUserId, int page, int size) {
        if (blockRepository.existsBlockBetween(currentUserId, authorId)) {
            throw ApiException.notFound("USER_NOT_FOUND", "User not found");
        }
        Page<UUID> ids = postRepository.findPostIdsByAuthorId(authorId,
                PageRequest.of(Math.max(page, 0), clampSize(size)));
        return toPageResponse(ids, currentUserId);
    }

    /** "View Memories": posts linked to an event the viewer can see ({@code GET /posts?eventId=}). */
    @Transactional(readOnly = true)
    public CursorPage<PostResponse> getEventPosts(UUID viewerId, UUID eventId, String cursor, int limit) {
        FeedCursor parsed = FeedCursor.parse(cursor);
        if (!eventRepository.isVisibleTo(eventId, viewerId)) {
            throw ApiException.notFound("EVENT_NOT_FOUND", "Event not found");
        }
        int safeLimit = clampSize(limit);
        return toCursorPage(postQueryRepository.findEventPostRefs(eventId, viewerId, parsed, safeLimit + 1),
                safeLimit, viewerId);
    }

    /** The viewer's saved posts, most recently saved first ({@code GET /users/me/bookmarks}). */
    @Transactional(readOnly = true)
    public CursorPage<PostResponse> getBookmarks(UUID viewerId, String cursor, int limit) {
        FeedCursor parsed = FeedCursor.parse(cursor);
        int safeLimit = clampSize(limit);
        return toCursorPage(postQueryRepository.findBookmarkRefs(viewerId, parsed, safeLimit + 1), safeLimit, viewerId);
    }

    /**
     * Loads posts for display in one batch (author, game, images, tags, liked, bookmarked), keyed
     * by id. Deleted posts, posts of deleted authors and posts of authors blocked either way are
     * omitted. Used by the feed and every list here.
     */
    @Transactional(readOnly = true)
    public Map<UUID, PostResponse> loadVisible(Collection<UUID> ids, UUID viewerId) {
        if (ids.isEmpty()) {
            return Map.of();
        }
        List<Post> posts = postRepository.findWithDetailsByIdIn(ids);
        postRepository.fetchTagsByIdIn(ids);
        Set<UUID> hidden = blockRepository.findBlockedEitherWay(viewerId);
        List<Post> visible = posts.stream()
                .filter(p -> p.getDeletedAt() == null
                        && p.getAuthor().getDeletedAt() == null
                        && !hidden.contains(p.getAuthor().getId()))
                .toList();
        Set<UUID> visibleIds = visible.stream().map(Post::getId).collect(Collectors.toSet());
        Set<UUID> liked = likedPostIds(viewerId, visibleIds);
        Set<UUID> bookmarked = postQueryRepository.findBookmarkedPostIds(viewerId, visibleIds);
        Map<UUID, PostResponse> result = new LinkedHashMap<>();
        for (Post p : visible) {
            result.put(p.getId(), PostResponse.from(p, liked.contains(p.getId()), bookmarked.contains(p.getId())));
        }
        return result;
    }

    // -------------------------------------------------------------------------
    // Single post
    // -------------------------------------------------------------------------

    @Transactional(readOnly = true)
    public PostResponse getPost(UUID postId, UUID currentUserId) {
        Post post = findVisiblePost(postId, currentUserId);
        boolean liked = postLikeRepository.existsById(new PostLikeId(postId, currentUserId));
        boolean bookmarked = !postQueryRepository.findBookmarkedPostIds(currentUserId, List.of(postId)).isEmpty();
        return PostResponse.from(post, liked, bookmarked);
    }

    // -------------------------------------------------------------------------
    // Create
    // -------------------------------------------------------------------------

    /**
     * Creates a post (FEATURES_COMPLETE 5.2). When a game is set, publishes a
     * {@link SessionPlayedEvent} for the author and every tagged user (the library package records
     * the plays after commit). Tagged users other than the author get a {@code POST_TAG}
     * notification.
     */
    @Transactional
    public PostResponse createPost(UUID userId, CreatePostRequest req) {
        User author = userRepository.findById(userId)
                .orElseThrow(() -> ApiException.notFound("User not found"));
        validatePlayedAt(req.playedAt());

        Post post = new Post();
        post.setAuthor(author);
        post.setCaption(blankToNull(req.caption()));
        post.setLocation(blankToNull(req.location()));
        post.setPlayedAt(req.playedAt());

        if (req.gameId() != null) {
            post.setGame(findGame(req.gameId()));
        }
        if (req.eventId() != null) {
            post.setEvent(findEventForMemories(req.eventId(), userId));
        }

        // Images — keys are R2 object keys; derive full public URL
        if (req.imageKeys() != null) {
            String publicBase = appProperties.getR2().getPublicUrl();
            for (int i = 0; i < req.imageKeys().size(); i++) {
                String key = req.imageKeys().get(i);
                validateImageKey(userId, key);
                PostImage img = new PostImage();
                img.setPost(post);
                img.setUrl(publicBase + "/" + key);
                img.setDisplayOrder(i);
                post.getImages().add(img);
            }
        }

        List<User> tagged = resolveTags(userId, req.taggedUserIds());
        tagged.forEach(user -> addTag(post, user));

        Post saved = postRepository.save(post);

        notifyTagged(saved, userId, tagged);
        if (saved.getGame() != null) {
            publishSession(saved, participants(userId, tagged));
        }
        feedCache.invalidateAfterCommit(userId);
        return PostResponse.from(saved, false, false);
    }

    // -------------------------------------------------------------------------
    // Edit
    // -------------------------------------------------------------------------

    /**
     * Edits a post within 48h of creation (author only). Newly tagged users are notified and, when
     * the post has a game, get a session recorded. Play counts are never decremented: neither for
     * removed tags nor for a replaced game (consistent with "not decremented on delete",
     * FEATURES_COMPLETE section 0). Setting a game on a post that had none, or changing it, records
     * the session for every current participant.
     */
    @Transactional
    public PostResponse updatePost(UUID userId, UUID postId, UpdatePostRequest req) {
        Post post = findActivePost(postId);
        if (!post.getAuthor().getId().equals(userId)) {
            throw ApiException.forbidden("FORBIDDEN", "You can only edit your own posts");
        }
        requireWithinWindow(post.getCreatedAt(), POST_EDIT_WINDOW);
        validatePlayedAt(req.playedAt());

        if (req.caption() != null) post.setCaption(blankToNull(req.caption()));
        if (req.location() != null) post.setLocation(blankToNull(req.location()));
        if (req.playedAt() != null) post.setPlayedAt(req.playedAt());

        UUID oldGameId = post.getGame() != null ? post.getGame().getId() : null;
        if (Boolean.TRUE.equals(req.clearGame())) {
            post.setGame(null);
        } else if (req.gameId() != null && !req.gameId().equals(oldGameId)) {
            post.setGame(findGame(req.gameId()));
        }
        UUID newGameId = post.getGame() != null ? post.getGame().getId() : null;
        boolean gameChanged = newGameId != null && !newGameId.equals(oldGameId);

        List<User> added = List.of();
        if (req.taggedUserIds() != null) {
            List<User> wanted = resolveTags(userId, req.taggedUserIds());
            Set<UUID> wantedIds = wanted.stream().map(User::getId).collect(Collectors.toSet());
            Set<UUID> currentIds = post.getTags().stream().map(t -> t.getUser().getId()).collect(Collectors.toSet());
            post.getTags().removeIf(t -> !wantedIds.contains(t.getUser().getId()));
            added = wanted.stream().filter(u -> !currentIds.contains(u.getId())).toList();
            added.forEach(user -> addTag(post, user));
        }

        post.setEditedAt(Instant.now());
        Post saved = postRepository.save(post);

        notifyTagged(saved, userId, added);
        if (gameChanged) {
            List<User> everyone = saved.getTags().stream().map(PostTag::getUser).toList();
            publishSession(saved, participants(userId, everyone));
        } else if (newGameId != null && !added.isEmpty()) {
            publishSession(saved, added.stream().map(User::getId).filter(id -> !id.equals(userId)).toList());
        }
        feedCache.invalidateAfterCommit(userId);

        boolean liked = postLikeRepository.existsById(new PostLikeId(postId, userId));
        boolean bookmarked = !postQueryRepository.findBookmarkedPostIds(userId, List.of(postId)).isEmpty();
        return PostResponse.from(saved, liked, bookmarked);
    }

    // -------------------------------------------------------------------------
    // Delete (soft)
    // -------------------------------------------------------------------------

    @Transactional
    public void deletePost(UUID userId, UUID postId) {
        Post post = findActivePost(postId);
        if (!post.getAuthor().getId().equals(userId)) {
            throw ApiException.forbidden("FORBIDDEN", "You can only delete your own posts");
        }
        post.setDeletedAt(Instant.now());
        postRepository.save(post);
        feedCache.invalidateAfterCommit(userId);
    }

    // -------------------------------------------------------------------------
    // Likes
    // -------------------------------------------------------------------------

    @Transactional
    public void likePost(UUID userId, UUID postId) {
        Post post = findVisiblePost(postId, userId);

        // Idempotent: a duplicate like inserts nothing and changes nothing
        if (postLikeRepository.insertIfAbsent(postId, userId) == 0)
            return;

        postRepository.incrementLikeCount(postId);

        // Notify author (not if liking own post)
        UUID authorId = post.getAuthor().getId();
        if (!userId.equals(authorId)) {
            notificationService.send(authorId, Notification.NotificationType.POST_LIKE, userId, postId, "POST");
        }
    }

    @Transactional
    public void unlikePost(UUID userId, UUID postId) {
        if (postLikeRepository.deleteByPostIdAndUserId(postId, userId) > 0) {
            postRepository.decrementLikeCount(postId);
        }
    }

    // -------------------------------------------------------------------------
    // Bookmarks
    // -------------------------------------------------------------------------

    /** Idempotent save ({@code POST /posts/{id}/bookmark}). */
    @Transactional
    public void bookmarkPost(UUID userId, UUID postId) {
        findVisiblePost(postId, userId);
        postQueryRepository.insertBookmark(userId, postId);
    }

    /** Idempotent unsave ({@code DELETE /posts/{id}/bookmark}); works even if the post is gone. */
    @Transactional
    public void unbookmarkPost(UUID userId, UUID postId) {
        postQueryRepository.deleteBookmark(userId, postId);
    }

    // -------------------------------------------------------------------------
    // Comments
    // -------------------------------------------------------------------------

    @Transactional
    public PostCommentResponse addComment(UUID userId, UUID postId, CreateCommentRequest req) {
        User author = userRepository.findById(userId)
                .orElseThrow(() -> ApiException.notFound("User not found"));
        Post post = findVisiblePost(postId, userId);

        PostComment comment = new PostComment();
        comment.setPost(post);
        comment.setAuthor(author);
        comment.setBody(req.body().trim());
        PostComment saved = postCommentRepository.save(comment);

        postRepository.incrementCommentCount(postId);

        // Notify post author (not if commenting on own post)
        UUID postAuthorId = post.getAuthor().getId();
        if (!userId.equals(postAuthorId)) {
            notificationService.send(postAuthorId, Notification.NotificationType.POST_COMMENT, userId, postId, "POST");
        }
        notifyMentions(post, userId, MentionParser.usernames(saved.getBody()));

        return PostCommentResponse.from(saved);
    }

    /** Edits a comment within 24h of creation (comment author only); only new mentions notify. */
    @Transactional
    public PostCommentResponse updateComment(UUID userId, UUID postId, UUID commentId, CreateCommentRequest req) {
        findVisiblePost(postId, userId);
        PostComment comment = postCommentRepository.findActive(postId, commentId)
                .orElseThrow(() -> ApiException.notFound("COMMENT_NOT_FOUND", "Comment not found"));
        if (!comment.getAuthor().getId().equals(userId)) {
            throw ApiException.forbidden("FORBIDDEN", "You can only edit your own comments");
        }
        requireWithinWindow(comment.getCreatedAt(), COMMENT_EDIT_WINDOW);

        Set<String> before = MentionParser.usernames(comment.getBody());
        comment.setBody(req.body().trim());
        comment.setEditedAt(Instant.now());
        PostComment saved = postCommentRepository.save(comment);

        Set<String> newMentions = new LinkedHashSet<>(MentionParser.usernames(saved.getBody()));
        newMentions.removeAll(before);
        notifyMentions(saved.getPost(), userId, newMentions);
        return PostCommentResponse.from(saved);
    }

    /** Soft-deletes a comment; allowed for the comment author and the post author. */
    @Transactional
    public void deleteComment(UUID userId, UUID postId, UUID commentId) {
        findVisiblePost(postId, userId);
        PostComment comment = postCommentRepository.findActive(postId, commentId)
                .orElseThrow(() -> ApiException.notFound("COMMENT_NOT_FOUND", "Comment not found"));
        boolean isCommentAuthor = comment.getAuthor().getId().equals(userId);
        boolean isPostAuthor = comment.getPost().getAuthor().getId().equals(userId);
        if (!isCommentAuthor && !isPostAuthor) {
            throw ApiException.forbidden("FORBIDDEN", "You cannot delete this comment");
        }
        comment.setDeletedAt(Instant.now());
        postCommentRepository.save(comment);
        postRepository.decrementCommentCount(postId);
    }

    @Transactional(readOnly = true)
    public PageResponse<PostCommentResponse> getComments(UUID postId, UUID currentUserId, int page, int size) {
        findVisiblePost(postId, currentUserId);
        Page<PostComment> comments = postCommentRepository.findVisibleByPostId(
                postId, currentUserId, PageRequest.of(Math.max(page, 0), clampSize(size)));
        return PageResponse.of(comments, PostCommentResponse::from);
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private Post findActivePost(UUID postId) {
        return postRepository.findActiveById(postId)
                .orElseThrow(() -> ApiException.notFound("POST_NOT_FOUND", "Post not found"));
    }

    /** Active post whose author has not blocked / been blocked by the viewer; otherwise 404. */
    private Post findVisiblePost(UUID postId, UUID viewerId) {
        Post post = findActivePost(postId);
        if (blockRepository.existsBlockBetween(viewerId, post.getAuthor().getId())) {
            throw ApiException.notFound("POST_NOT_FOUND", "Post not found");
        }
        return post;
    }

    private Game findGame(UUID gameId) {
        return gameRepository.findById(gameId)
                .orElseThrow(() -> ApiException.notFound("GAME_NOT_FOUND", "Game not found"));
    }

    /** The event a post's memories belong to: visible to the author, who hosted or attended it. */
    private Event findEventForMemories(UUID eventId, UUID authorId) {
        Event event = eventRepository.findVisibleById(eventId, authorId)
                .orElseThrow(() -> ApiException.notFound("EVENT_NOT_FOUND", "Event not found"));
        boolean host = event.getHost().getId().equals(authorId);
        boolean attended = eventParticipantRepository.findByEventIdAndUserId(eventId, authorId)
                .map(p -> p.getStatus() == EventParticipant.RsvpStatus.ACCEPTED)
                .orElse(false);
        if (!host && !attended) {
            throw ApiException.forbidden("NOT_PARTICIPANT", "Only the host and attendees can post to this event");
        }
        return event;
    }

    /**
     * Resolves requested tags: the author may tag themselves and accepted friends. Users blocked
     * either way are dropped silently (FEATURES_COMPLETE 2.2: "tag is silently dropped"), as are
     * unknown or deleted users; anyone else who is not a friend fails with 403 NOT_FRIENDS.
     */
    private List<User> resolveTags(UUID authorId, List<UUID> requested) {
        if (requested == null || requested.isEmpty()) {
            return List.of();
        }
        Set<UUID> ids = new LinkedHashSet<>(requested);
        ids.remove(null);
        Set<UUID> blocked = blockRepository.findBlockedEitherWay(authorId);
        ids.removeAll(blocked);
        Set<UUID> friends = new HashSet<>(friendRequestRepository.findFriendIds(authorId));
        for (UUID id : ids) {
            if (!id.equals(authorId) && !friends.contains(id)) {
                throw ApiException.forbidden("NOT_FRIENDS", "You can only tag your friends");
            }
        }
        if (ids.isEmpty()) {
            return List.of();
        }
        Map<UUID, User> users = userRepository.findAllById(ids).stream()
                .filter(u -> u.getDeletedAt() == null)
                .collect(Collectors.toMap(User::getId, Function.identity()));
        return ids.stream().map(users::get).filter(Objects::nonNull).toList();
    }

    private static void addTag(Post post, User user) {
        PostTag tag = new PostTag();
        tag.setPost(post);
        tag.setUser(user);
        post.getTags().add(tag);
    }

    private void notifyTagged(Post post, UUID authorId, List<User> tagged) {
        for (User user : tagged) {
            if (!user.getId().equals(authorId)) {
                notificationService.send(user.getId(), Notification.NotificationType.POST_TAG, authorId,
                        post.getId(), "POST");
            }
        }
    }

    /**
     * Notifies mentioned users who exist, are not the commenter or the post author (who already
     * gets POST_COMMENT), and are not blocked either way with the commenter or the post author.
     */
    private void notifyMentions(Post post, UUID commenterId, Set<String> usernames) {
        if (usernames.isEmpty()) {
            return;
        }
        UUID postAuthorId = post.getAuthor().getId();
        Set<UUID> hidden = new HashSet<>(blockRepository.findBlockedEitherWay(commenterId));
        hidden.addAll(blockRepository.findBlockedEitherWay(postAuthorId));
        for (User user : postCommentRepository.findActiveUsersByUsernames(usernames)) {
            UUID id = user.getId();
            if (!id.equals(commenterId) && !id.equals(postAuthorId) && !hidden.contains(id)) {
                notificationService.send(id, Notification.NotificationType.COMMENT_MENTION, commenterId,
                        post.getId(), "POST");
            }
        }
    }

    private static List<UUID> participants(UUID authorId, List<User> tagged) {
        Set<UUID> ids = new LinkedHashSet<>();
        ids.add(authorId);
        tagged.forEach(u -> ids.add(u.getId()));
        return List.copyOf(ids);
    }

    private void publishSession(Post post, List<UUID> userIds) {
        if (userIds.isEmpty()) {
            return;
        }
        Instant playedAt = post.getPlayedAt() != null ? post.getPlayedAt() : post.getCreatedAt();
        eventPublisher.publishEvent(new SessionPlayedEvent(userIds, post.getGame().getId(), playedAt, post.getId()));
    }

    private static void validatePlayedAt(Instant playedAt) {
        if (playedAt != null && playedAt.isAfter(Instant.now().plus(PLAYED_AT_SKEW))) {
            throw ApiException.badRequest("PLAYED_AT_IN_FUTURE", "playedAt cannot be in the future");
        }
    }

    private static void requireWithinWindow(Instant createdAt, Duration window) {
        if (createdAt.plus(window).isBefore(Instant.now())) {
            throw ApiException.forbidden("EDIT_WINDOW_EXPIRED", "This can no longer be edited");
        }
    }

    private static String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    private static int clampSize(int size) {
        return Math.clamp(size, 1, MAX_PAGE_SIZE);
    }

    /**
     * Only keys issued by the upload endpoints for this user are accepted
     * ("uploads/{userId}/{file}"), so a post cannot reference another user's object.
     */
    static void validateImageKey(UUID userId, String key) {
        String prefix = "uploads/" + userId + "/";
        if (key == null
                || !key.startsWith(prefix)
                || key.length() == prefix.length()
                || key.contains("..")
                || key.indexOf('/', prefix.length()) >= 0
                || key.indexOf('\\') >= 0) {
            throw ApiException.badRequest("INVALID_IMAGE_KEY", "Invalid image key");
        }
    }

    /** Builds a cursor page from {@code limit + 1} keyset refs, hydrating in one batch. */
    private CursorPage<PostResponse> toCursorPage(List<PostQueryRepository.Ref> refs, int limit, UUID viewerId) {
        boolean hasMore = refs.size() > limit;
        List<PostQueryRepository.Ref> page = hasMore ? refs.subList(0, limit) : refs;
        Map<UUID, PostResponse> posts = loadVisible(page.stream().map(PostQueryRepository.Ref::id).toList(), viewerId);
        List<PostResponse> items = page.stream().map(r -> posts.get(r.id())).filter(Objects::nonNull).toList();
        String next = hasMore ? FeedCursor.encode(page.get(page.size() - 1).at(), page.get(page.size() - 1).id()) : null;
        return new CursorPage<>(items, next, hasMore);
    }

    /** Loads the page's posts with all associations in two queries, preserving the page order. */
    private PageResponse<PostResponse> toPageResponse(Page<UUID> idPage, UUID currentUserId) {
        PageMeta meta = new PageMeta(
                idPage.getNumber() + 1,
                idPage.getSize(),
                idPage.getTotalElements(),
                idPage.hasNext()
        );
        List<UUID> ids = idPage.getContent();
        Map<UUID, PostResponse> byId = loadVisible(ids, currentUserId);
        List<PostResponse> data = ids.stream().map(byId::get).filter(Objects::nonNull).toList();
        return new PageResponse<>(data, meta);
    }

    private Set<UUID> likedPostIds(UUID userId, Set<UUID> postIds) {
        if (userId == null || postIds.isEmpty())
            return Set.of();
        return postLikeRepository.findLikedPostIds(postIds, userId)
                .stream().map(PostLikeId::getPostId).collect(Collectors.toSet());
    }
}
