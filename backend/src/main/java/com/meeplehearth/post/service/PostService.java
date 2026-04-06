package com.meeplehearth.post.service;

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
import java.util.Set;
import java.util.UUID;
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

    public PostService(PostRepository postRepository,
            PostLikeRepository postLikeRepository,
            PostCommentRepository postCommentRepository,
            UserRepository userRepository,
            GameRepository gameRepository,
            AppProperties appProperties,
            FriendRequestRepository friendRequestRepository,
            NotificationService notificationService) {
        this.postRepository = postRepository;
        this.postLikeRepository = postLikeRepository;
        this.postCommentRepository = postCommentRepository;
        this.userRepository = userRepository;
        this.gameRepository = gameRepository;
        this.appProperties = appProperties;
        this.friendRequestRepository = friendRequestRepository;
        this.notificationService = notificationService;
    }

    // -------------------------------------------------------------------------
    // Feed
    // -------------------------------------------------------------------------

    @Transactional(readOnly = true)
    public PageResponse<PostResponse> getFeed(UUID currentUserId, int page, int size) {
        List<UUID> friendIds = friendRequestRepository.findFriendIds(currentUserId);
        List<UUID> feedIds = new ArrayList<>(friendIds);
        feedIds.add(currentUserId);
        Page<Post> posts = postRepository.findFeedForUser(feedIds, PageRequest.of(page, size));
        Set<UUID> likedPostIds = likedPostIds(currentUserId, posts);
        return PageResponse.of(posts, p -> PostResponse.from(p, likedPostIds.contains(p.getId())));
    }

    @Transactional(readOnly = true)
    public PageResponse<PostResponse> getUserPosts(UUID authorId, UUID currentUserId, int page, int size) {
        Page<Post> posts = postRepository.findByAuthorId(authorId, PageRequest.of(page, size));
        Set<UUID> likedPostIds = likedPostIds(currentUserId, posts);
        return PageResponse.of(posts, p -> PostResponse.from(p, likedPostIds.contains(p.getId())));
    }

    // -------------------------------------------------------------------------
    // Single post
    // -------------------------------------------------------------------------

    @Transactional(readOnly = true)
    public PostResponse getPost(UUID postId, UUID currentUserId) {
        Post post = findActivePost(postId);
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
        PostLikeId likeId = new PostLikeId(postId, userId);
        if (postLikeRepository.existsById(likeId))
            return;

        postLikeRepository.save(new PostLike(likeId));

        Post post = findActivePost(postId);
        post.setLikeCount(post.getLikeCount() + 1);
        postRepository.save(post);

        // Notify author (not if liking own post)
        UUID authorId = post.getAuthor().getId();
        if (!userId.equals(authorId)) {
            notificationService.send(authorId, Notification.NotificationType.POST_LIKE, userId, postId, "POST");
        }
    }

    @Transactional
    public void unlikePost(UUID userId, UUID postId) {
        PostLikeId likeId = new PostLikeId(postId, userId);
        if (!postLikeRepository.existsById(likeId))
            return;

        postLikeRepository.deleteById(likeId);

        Post post = findActivePost(postId);
        post.setLikeCount(Math.max(0, post.getLikeCount() - 1));
        postRepository.save(post);
    }

    // -------------------------------------------------------------------------
    // Comments
    // -------------------------------------------------------------------------

    @Transactional
    public PostCommentResponse addComment(UUID userId, UUID postId, CreateCommentRequest req) {
        User author = userRepository.findById(userId)
                .orElseThrow(() -> ApiException.notFound("User not found"));
        Post post = findActivePost(postId);

        PostComment comment = new PostComment();
        comment.setPost(post);
        comment.setAuthor(author);
        comment.setBody(req.body());
        PostComment saved = postCommentRepository.save(comment);

        post.setCommentCount(post.getCommentCount() + 1);
        postRepository.save(post);

        // Notify post author (not if commenting on own post)
        UUID authorId = post.getAuthor().getId();
        if (!userId.equals(authorId)) {
            notificationService.send(authorId, Notification.NotificationType.POST_COMMENT, userId, postId, "POST");
        }

        return PostCommentResponse.from(saved);
    }

    @Transactional(readOnly = true)
    public PageResponse<PostCommentResponse> getComments(UUID postId, int page, int size) {
        Page<PostComment> comments = postCommentRepository.findByPostId(postId, PageRequest.of(page, size));
        return PageResponse.of(comments, PostCommentResponse::from);
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private Post findActivePost(UUID postId) {
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> ApiException.notFound("POST_NOT_FOUND", "Post not found"));
        if (post.getDeletedAt() != null) {
            throw ApiException.notFound("POST_NOT_FOUND", "Post not found");
        }
        return post;
    }

    private Set<UUID> likedPostIds(UUID userId, Page<Post> posts) {
        if (userId == null)
            return Set.of();
        Set<UUID> postIds = posts.stream().map(Post::getId).collect(Collectors.toSet());
        return postLikeRepository.findLikedPostIds(postIds, userId)
                .stream().map(PostLikeId::getPostId).collect(Collectors.toSet());
    }
}
