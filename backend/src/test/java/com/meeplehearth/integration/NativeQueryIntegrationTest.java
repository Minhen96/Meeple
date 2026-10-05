package com.meeplehearth.integration;

import com.meeplehearth.post.repository.PostLikeRepository;
import com.meeplehearth.post.repository.PostRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Runs native SQL and migration-defined constraints against the real Postgres schema,
 * which unit tests with mocked repositories cannot cover.
 */
@SpringBootTest
@Transactional
class NativeQueryIntegrationTest {

    @Autowired private JdbcTemplate jdbc;
    @Autowired private PostRepository postRepository;
    @Autowired private PostLikeRepository postLikeRepository;

    private UUID userId;
    private UUID postId;
    private UUID gameId;

    @BeforeEach
    void seed() {
        userId = UUID.randomUUID();
        postId = UUID.randomUUID();
        gameId = UUID.randomUUID();
        String suffix = userId.toString().substring(0, 8);
        jdbc.update("INSERT INTO users (id, username, email) VALUES (?, ?, ?)",
                userId, "it_" + suffix, "it_" + suffix + "@example.test");
        jdbc.update("INSERT INTO posts (id, author_id) VALUES (?, ?)", postId, userId);
        jdbc.update("INSERT INTO games (id, bgg_id, name_en) VALUES (?, ?, ?)",
                gameId, -Math.abs(userId.hashCode() % 1_000_000) - 1, "Integration Game");
    }

    @Test
    void likeInsertIsIdempotent() {
        assertThat(postLikeRepository.insertIfAbsent(postId, userId)).isEqualTo(1);
        assertThat(postLikeRepository.insertIfAbsent(postId, userId)).isZero();
        assertThat(postLikeRepository.deleteByPostIdAndUserId(postId, userId)).isEqualTo(1);
        assertThat(postLikeRepository.deleteByPostIdAndUserId(postId, userId)).isZero();
    }

    @Test
    void counterUpdatesAreAtomicAndNeverNegative() {
        postRepository.incrementLikeCount(postId);
        postRepository.incrementLikeCount(postId);
        postRepository.decrementLikeCount(postId);
        postRepository.decrementLikeCount(postId);
        postRepository.decrementLikeCount(postId);
        postRepository.incrementCommentCount(postId);

        assertThat(jdbc.queryForObject("SELECT like_count FROM posts WHERE id = ?", Integer.class, postId)).isZero();
        assertThat(jdbc.queryForObject("SELECT comment_count FROM posts WHERE id = ?", Integer.class, postId)).isEqualTo(1);
    }

    @Test
    void matchRequestUniquenessOnlyAppliesToActiveRows() {
        String insert = "INSERT INTO match_requests (user_id, game_id, status) VALUES (?, ?, ?)";
        jdbc.update(insert, userId, gameId, "CANCELLED");
        jdbc.update(insert, userId, gameId, "EXPIRED");
        jdbc.update(insert, userId, gameId, "ACTIVE");

        assertThatThrownBy(() -> jdbc.update(insert, userId, gameId, "ACTIVE"))
                .hasMessageContaining("uq_match_requests_user_game_active");
    }
}
