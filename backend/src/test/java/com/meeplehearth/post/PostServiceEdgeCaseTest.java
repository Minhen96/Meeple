package com.meeplehearth.post;

import com.meeplehearth.common.dto.PageResponse;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.config.AppProperties;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.notification.service.NotificationService;
import com.meeplehearth.post.dto.CreateCommentRequest;
import com.meeplehearth.post.dto.CreatePostRequest;
import com.meeplehearth.post.dto.PostResponse;
import com.meeplehearth.post.entity.Post;
import com.meeplehearth.post.repository.PostCommentRepository;
import com.meeplehearth.post.repository.PostLikeRepository;
import com.meeplehearth.post.repository.PostQueryRepository;
import com.meeplehearth.post.repository.PostRepository;
import com.meeplehearth.event.repository.EventParticipantRepository;
import com.meeplehearth.event.repository.EventRepository;
import com.meeplehearth.feed.service.FeedCache;
import org.springframework.context.ApplicationEventPublisher;
import com.meeplehearth.post.service.PostService;
import com.meeplehearth.social.repository.BlockRepository;
import com.meeplehearth.social.repository.FriendRequestRepository;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Answers;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;

import java.util.Arrays;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** PostService paths the API cannot reach (the JWT filter guarantees the caller exists) and feed race handling. */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class PostServiceEdgeCaseTest {

    @Mock PostRepository postRepository;
    @Mock PostLikeRepository postLikeRepository;
    @Mock PostCommentRepository postCommentRepository;
    @Mock UserRepository userRepository;
    @Mock GameRepository gameRepository;
    @Mock(answer = Answers.RETURNS_DEEP_STUBS) AppProperties appProperties;
    @Mock FriendRequestRepository friendRequestRepository;
    @Mock NotificationService notificationService;
    @Mock BlockRepository blockRepository;
    @Mock PostQueryRepository postQueryRepository;
    @Mock EventRepository eventRepository;
    @Mock EventParticipantRepository eventParticipantRepository;
    @Mock ApplicationEventPublisher eventPublisher;
    @Mock FeedCache feedCache;

    PostService service;
    final UUID userId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new PostService(postRepository, postLikeRepository, postCommentRepository, postQueryRepository,
                userRepository, gameRepository, eventRepository, eventParticipantRepository, appProperties,
                friendRequestRepository, notificationService, blockRepository, eventPublisher, feedCache);
        User me = new User();
        me.setId(userId);
        when(userRepository.findById(userId)).thenReturn(Optional.of(me));
        when(appProperties.getR2().getPublicUrl()).thenReturn("https://cdn.example.test");
    }

    @Test
    void nullOrBackslashImageKeysAreRejected() {
        for (String key : Arrays.asList(null, "uploads/" + userId + "/a\\b.jpg")) {
            assertThatThrownBy(() -> service.createPost(userId, request(key)))
                    .as("key %s", key)
                    .isInstanceOfSatisfying(ApiException.class,
                            e -> assertThat(e.getCode()).isEqualTo("INVALID_IMAGE_KEY"));
        }
        verify(postRepository, never()).save(any());
    }

    @Test
    void unknownCallerCannotPostOrComment() {
        UUID ghost = UUID.randomUUID();
        when(userRepository.findById(ghost)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.createPost(ghost, request()))
                .isInstanceOfSatisfying(ApiException.class,
                        e -> assertThat(e.getStatus()).isEqualTo(HttpStatus.NOT_FOUND));
        assertThatThrownBy(() -> service.addComment(ghost, UUID.randomUUID(), new CreateCommentRequest("hi")))
                .isInstanceOfSatisfying(ApiException.class,
                        e -> assertThat(e.getStatus()).isEqualTo(HttpStatus.NOT_FOUND));
        verify(postRepository, never()).save(any());
        verify(postCommentRepository, never()).save(any());
    }

    @Test
    void feedSkipsPostsThatVanishedBetweenPagingAndLoadingAndKeepsPageOrder() {
        UUID newer = UUID.randomUUID();
        UUID vanished = UUID.randomUUID();
        UUID older = UUID.randomUUID();
        when(friendRequestRepository.findFriendIds(userId)).thenReturn(List.of());
        when(postRepository.findFeedPostIds(eq(List.of(userId)), eq(userId), any()))
                .thenReturn(new PageImpl<>(List.of(newer, vanished, older), PageRequest.of(0, 3), 3));
        Post olderPost = post(older);
        Post newerPost = post(newer);
        // Detail query order is not guaranteed and DISTINCT may still yield duplicates; one post is gone
        when(postRepository.findWithDetailsByIdIn(anyCollection())).thenReturn(List.of(olderPost, newerPost, olderPost));
        when(postLikeRepository.findLikedPostIds(any(), eq(userId))).thenReturn(Set.of());

        PageResponse<PostResponse> page = service.getFeed(userId, 0, 3);

        assertThat(page.data()).extracting(PostResponse::id).containsExactly(newer, older);
        assertThat(page.meta().total()).isEqualTo(3);
    }

    private Post post(UUID id) {
        User author = new User();
        author.setId(UUID.randomUUID());
        Post p = new Post();
        p.setId(id);
        p.setAuthor(author);
        return p;
    }

    private static CreatePostRequest request(String... keys) {
        return new CreatePostRequest("caption", null, null, null, null, null,
                keys.length == 0 ? null : Arrays.asList(keys));
    }
}
