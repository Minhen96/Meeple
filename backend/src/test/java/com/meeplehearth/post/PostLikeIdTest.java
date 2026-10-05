package com.meeplehearth.post;

import com.meeplehearth.post.entity.PostLike;
import com.meeplehearth.post.entity.PostLikeId;
import org.junit.jupiter.api.Test;

import java.util.Set;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/** The composite key drives liked-post lookups (Set membership) and JPA identity, so equality must be by value. */
class PostLikeIdTest {

    private final UUID post = UUID.randomUUID();
    private final UUID user = UUID.randomUUID();

    @Test
    void equalityIsByPostAndUser() {
        PostLikeId id = new PostLikeId(post, user);

        assertThat(id).isEqualTo(id);
        assertThat(id).isEqualTo(new PostLikeId(post, user)).hasSameHashCodeAs(new PostLikeId(post, user));
        assertThat(id).isNotEqualTo(new PostLikeId(post, UUID.randomUUID()));
        assertThat(id).isNotEqualTo(new PostLikeId(UUID.randomUUID(), user));
        assertThat(id).isNotEqualTo(new PostLikeId(user, post)); // order matters
        assertThat(id).isNotEqualTo(null);
        assertThat(id).isNotEqualTo(post);
        assertThat(new PostLikeId()).isEqualTo(new PostLikeId());
        assertThat(Set.of(new PostLikeId(post, user))).contains(new PostLikeId(post, user));
        assertThat(id.getPostId()).isEqualTo(post);
        assertThat(id.getUserId()).isEqualTo(user);
    }

    @Test
    void likeCarriesItsKeyAndCreationTime() {
        PostLike like = new PostLike(new PostLikeId(post, user));
        assertThat(like.getId()).isEqualTo(new PostLikeId(post, user));
        assertThat(like.getCreatedAt()).isNotNull();

        PostLike empty = new PostLike();
        empty.setId(new PostLikeId(post, user));
        assertThat(empty.getId()).isEqualTo(like.getId());
    }
}
