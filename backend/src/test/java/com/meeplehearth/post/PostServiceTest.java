package com.meeplehearth.post;

import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.config.AppProperties;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.notification.service.NotificationService;
import com.meeplehearth.post.dto.CreatePostRequest;
import com.meeplehearth.post.dto.PostResponse;
import com.meeplehearth.post.entity.Post;
import com.meeplehearth.post.repository.PostCommentRepository;
import com.meeplehearth.post.repository.PostLikeRepository;
import com.meeplehearth.post.repository.PostRepository;
import com.meeplehearth.post.service.PostService;
import com.meeplehearth.social.repository.BlockRepository;
import com.meeplehearth.social.repository.FriendRequestRepository;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.Answers;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.http.HttpStatus;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class PostServiceTest {

    @Mock PostRepository postRepository;
    @Mock PostLikeRepository postLikeRepository;
    @Mock PostCommentRepository postCommentRepository;
    @Mock UserRepository userRepository;
    @Mock GameRepository gameRepository;
    @Mock(answer = Answers.RETURNS_DEEP_STUBS) AppProperties appProperties;
    @Mock FriendRequestRepository friendRequestRepository;
    @Mock NotificationService notificationService;
    @Mock BlockRepository blockRepository;

    PostService service;
    final UUID userId = UUID.randomUUID();
    final UUID authorId = UUID.randomUUID();
    User me;

    @BeforeEach
    void setUp() {
        service = new PostService(postRepository, postLikeRepository, postCommentRepository, userRepository,
                gameRepository, appProperties, friendRequestRepository, notificationService, blockRepository);
        me = new User();
        me.setId(userId);
        when(userRepository.findById(userId)).thenReturn(Optional.of(me));
        when(appProperties.getR2().getPublicUrl()).thenReturn("https://cdn.example.test");
        when(postRepository.save(any(Post.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    // -------------------------------------------------------------------------
    // Image key validation
    // -------------------------------------------------------------------------

    @Test
    void acceptsOwnUploadKey() {
        String key = "uploads/" + userId + "/" + UUID.randomUUID() + ".jpg";

        PostResponse response = service.createPost(userId, request(key));

        assertThat(response.imageUrls()).containsExactly("https://cdn.example.test/" + key);
    }

    @ParameterizedTest
    @ValueSource(strings = {
            "uploads/OTHER/x.jpg",                 // another user's prefix
            "avatars/SELF/x.jpg",                  // wrong top-level prefix
            "uploads/SELF/../OTHER/x.jpg",         // traversal
            "uploads/SELF/",                       // no file name
            "uploads/SELF/nested/x.jpg",           // extra path segment
            "https://evil.example/x.jpg"           // absolute URL
    })
    void rejectsForeignOrMalformedKeys(String template) {
        String key = template.replace("SELF", userId.toString()).replace("OTHER", UUID.randomUUID().toString());

        assertThatThrownBy(() -> service.createPost(userId, request(key)))
                .isInstanceOf(ApiException.class)
                .satisfies(e -> {
                    assertThat(((ApiException) e).getStatus()).isEqualTo(HttpStatus.BAD_REQUEST);
                    assertThat(((ApiException) e).getCode()).isEqualTo("INVALID_IMAGE_KEY");
                });
        verify(postRepository, never()).save(any());
    }

    // -------------------------------------------------------------------------
    // Likes
    // -------------------------------------------------------------------------

    @Test
    void doubleLikeIsANoOp() {
        UUID postId = activePostByOtherAuthor();
        when(postLikeRepository.insertIfAbsent(postId, userId)).thenReturn(0);

        service.likePost(userId, postId);

        verify(postRepository, never()).incrementLikeCount(any());
        verify(notificationService, never()).send(any(), any(), any(), any(), any());
    }

    @Test
    void firstLikeIncrementsAndNotifies() {
        UUID postId = activePostByOtherAuthor();
        when(postLikeRepository.insertIfAbsent(postId, userId)).thenReturn(1);

        service.likePost(userId, postId);

        verify(postRepository).incrementLikeCount(postId);
        verify(notificationService).send(any(), any(), any(), any(), any());
    }

    @Test
    void unlikeWithoutExistingLikeDoesNotDecrement() {
        UUID postId = UUID.randomUUID();
        when(postLikeRepository.deleteByPostIdAndUserId(postId, userId)).thenReturn(0);

        service.unlikePost(userId, postId);

        verify(postRepository, never()).decrementLikeCount(any());
    }

    @Test
    void likeOnPostOfBlockedAuthorIs404() {
        UUID postId = activePostByOtherAuthor();
        when(blockRepository.existsBlockBetween(userId, authorId)).thenReturn(true);

        assertThatThrownBy(() -> service.likePost(userId, postId))
                .isInstanceOf(ApiException.class)
                .satisfies(e -> assertThat(((ApiException) e).getStatus()).isEqualTo(HttpStatus.NOT_FOUND));
        verify(postLikeRepository, never()).insertIfAbsent(any(), any());
    }

    private UUID activePostByOtherAuthor() {
        User author = new User();
        author.setId(authorId);
        Post post = new Post();
        UUID postId = UUID.randomUUID();
        post.setId(postId);
        post.setAuthor(author);
        when(postRepository.findActiveById(postId)).thenReturn(Optional.of(post));
        return postId;
    }

    private static CreatePostRequest request(String imageKey) {
        return new CreatePostRequest("caption", null, null, null, null, null, List.of(imageKey));
    }
}
