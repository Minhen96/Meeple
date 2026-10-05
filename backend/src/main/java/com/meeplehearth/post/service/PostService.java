package com.meeplehearth.post.service;

import com.meeplehearth.common.dto.PageMeta;
import com.meeplehearth.common.dto.PageResponse;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.config.AppProperties;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.post.dto.*;
import com.meeplehearth.post.entity.*;
import com.meeplehearth.post.repository.*;
import com.meeplehearth.notification.entity.Notification;
import com.meeplehearth.notification.service.NotificationService;
import com.meeplehearth.social.repository.BlockRepository;
import com.meeplehearth.social.repository.FriendRequestRepository;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
public class PostService {

    private final PostRepository postRepository;
    private final PostLikeRepository postLikeRepository;
    private final PostCommentRepository postCommentRepository;
    private final UserRepository userRepository;
    private final GameRepository gameRepository;
    private final AppProperties appProperties;
    private final FriendRequestRepository friendRequestRepository;
    private final NotificationService notificationService;
    private final BlockRepository blockRepository;

    public PostService(PostRepository postRepository,
            PostLikeRepository postLikeRepository,
            PostCommentRepository postCommentRepository,
            UserRepository userRepository,
            GameRepository gameRepository,
            AppProperties appProperties,
            FriendRequestRepository friendRequestRepository,
            NotificationService notificationService,
            BlockRepository blockRepository) {
        this.postRepository = postRepository;
        this.postLikeRepository = postLikeRepository;
        this.postCommentRepository = postCommentRepository;
        this.userRepository = userRepository;
        this.gameRepository = gameRepository;
        this.appProperties = appProperties;
        this.friendRequestRepository = friendRequestRepository;
        this.notificationService = notificationService;
        this.blockRepository = blockRepository;
    }

    // -------------------------------------------------------------------------
    // Feed
    // -------------------------------------------------------------------------

    @Transactional(readOnly = true)
    public PageResponse<PostResponse> getFeed(UUID currentUserId, int page, int size) {
        List<UUID> friendIds = friendRequestRepository.findFriendIds(currentUserId);
        List<UUID> feedIds = new ArrayList<>(friendIds);
        feedIds.add(currentUserId);
        Page<UUID> ids = postRepository.findFeedPostIds(feedIds, currentUserId, PageRequest.of(page, size));
        return toPageResponse(ids, currentUserId);
    }

    @Transactional(readOnly = true)
    public PageResponse<PostResponse> getUserPosts(UUID authorId, UUID currentUserId, int page, int size) {
        if (blockRepository.existsBlockBetween(currentUserId, authorId)) {
            throw ApiException.notFound("USER_NOT_FOUND", "User not found");
        }
        Page<UUID> ids = postRepository.findPostIdsByAuthorId(authorId, PageRequest.of(page, size));
        return toPageResponse(ids, currentUserId);
    }

    // -------------------------------------------------------------------------
    // Single post
    // -------------------------------------------------------------------------

    @Transactional(readOnly = true)
    public PostResponse getPost(UUID postId, UUID currentUserId) {
        Post post = findVisiblePost(postId, currentUserId);
        boolean liked = postLikeRepository.existsById(new PostLikeId(postId, currentUserId));
        return PostResponse.from(post, liked);
    }

    // -------------------------------------------------------------------------
    // Create
    // -------------------------------------------------------------------------

    @Transactional
    public PostResponse createPost(UUID userId, CreatePostRequest req) {
        User author = userRepository.findById(userId)
                .orElseThrow(() -> ApiException.notFound("User not found"));

        Post post = new Post();
        post.setAuthor(author);
        post.setCaption(req.caption());
        post.setLocation(req.location());
        post.setPlayedAt(req.playedAt());

        if (req.gameId() != null) {
            Game game = gameRepository.findById(req.gameId())
                    .orElseThrow(() -> ApiException.notFound("GAME_NOT_FOUND", "Game not found"));
            post.setGame(game);
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

        // Tagged users
        if (req.taggedUserIds() != null) {
            for (UUID taggedId : req.taggedUserIds()) {
                userRepository.findById(taggedId).ifPresent(tagged -> {
                    PostTag tag = new PostTag();
                    tag.setPost(post);
                    tag.setUser(tagged);
                    post.getTags().add(tag);
                });
            }
        }

        Post saved = postRepository.save(post);
        return PostResponse.from(saved, false);
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
        comment.setBody(req.body());
        PostComment saved = postCommentRepository.save(comment);

        postRepository.incrementCommentCount(postId);

        // Notify post author (not if commenting on own post)
        UUID authorId = post.getAuthor().getId();
        if (!userId.equals(authorId)) {
            notificationService.send(authorId, Notification.NotificationType.POST_COMMENT, userId, postId, "POST");
        }

        return PostCommentResponse.from(saved);
    }

    @Transactional(readOnly = true)
    public PageResponse<PostCommentResponse> getComments(UUID postId, UUID currentUserId, int page, int size) {
        findVisiblePost(postId, currentUserId);
        Page<PostComment> comments = postCommentRepository.findVisibleByPostId(
                postId, currentUserId, PageRequest.of(page, size));
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

    /** Loads the page's posts with all associations in two queries, preserving the page order. */
    private PageResponse<PostResponse> toPageResponse(Page<UUID> idPage, UUID currentUserId) {
        PageMeta meta = new PageMeta(
                idPage.getNumber() + 1,
                idPage.getSize(),
                idPage.getTotalElements(),
                idPage.hasNext()
        );
        List<UUID> ids = idPage.getContent();
        if (ids.isEmpty()) {
            return new PageResponse<>(List.of(), meta);
        }
        Map<UUID, Post> byId = postRepository.findWithDetailsByIdIn(ids).stream()
                .collect(Collectors.toMap(Post::getId, Function.identity(), (a, b) -> a));
        postRepository.fetchTagsByIdIn(ids);
        Set<UUID> likedPostIds = likedPostIds(currentUserId, byId.keySet());

        List<PostResponse> data = ids.stream()
                .map(byId::get)
                .filter(Objects::nonNull)
                .map(p -> PostResponse.from(p, likedPostIds.contains(p.getId())))
                .toList();
        return new PageResponse<>(data, meta);
    }

    private Set<UUID> likedPostIds(UUID userId, Set<UUID> postIds) {
        if (userId == null || postIds.isEmpty())
            return Set.of();
        return postLikeRepository.findLikedPostIds(postIds, userId)
                .stream().map(PostLikeId::getPostId).collect(Collectors.toSet());
    }
}
