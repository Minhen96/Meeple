package com.meeplehearth.post;

import com.fasterxml.jackson.databind.JsonNode;
import com.meeplehearth.support.social.ApiIntegrationTestBase;
import jakarta.servlet.http.Cookie;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Posts API end to end: JWT auth → PostController → PostService → real Postgres. */
class PostApiIntegrationTest extends ApiIntegrationTestBase {

    private static final String PUBLIC_BASE = "http://localhost:9000/meeple-media";

    // -------------------------------------------------------------------------
    // Create
    // -------------------------------------------------------------------------

    @Test
    void createPostPersistsImagesInOrderGameAndExistingTaggedUsers() throws Exception {
        UUID author = user();
        UUID tagged = user();
        friends(author, tagged);
        UUID gameId = game(2, 4);
        String key1 = "uploads/" + author + "/first.jpg";
        String key2 = "uploads/" + author + "/second.webp";
        Instant playedAt = Instant.parse("2026-09-01T18:00:00Z");

        Map<String, Object> body = new HashMap<>();
        body.put("caption", "Great game night");
        body.put("location", "Taipei");
        body.put("playedAt", playedAt.toString());
        body.put("gameId", gameId);
        body.put("imageKeys", List.of(key1, key2));
        body.put("taggedUserIds", List.of(tagged, tagged)); // duplicates collapse to one tag

        JsonNode data = json(mvc.perform(post("/api/v1/posts").with(as(author))
                        .contentType(MediaType.APPLICATION_JSON).content(toJson(body)))
                .andExpect(status().isCreated())
                .andReturn()).get("data");

        UUID postId = UUID.fromString(data.get("id").asText());
        assertThat(data.get("author").get("id").asText()).isEqualTo(author.toString());
        assertThat(data.get("caption").asText()).isEqualTo("Great game night");
        assertThat(data.get("location").asText()).isEqualTo("Taipei");
        assertThat(Instant.parse(data.get("playedAt").asText())).isEqualTo(playedAt);
        assertThat(data.get("imageUrls")).extracting(JsonNode::asText)
                .containsExactly(PUBLIC_BASE + "/" + key1, PUBLIC_BASE + "/" + key2);
        assertThat(data.get("game").get("id").asText()).isEqualTo(gameId.toString());
        assertThat(data.get("taggedUsers")).hasSize(1);
        assertThat(data.get("taggedUsers").get(0).get("id").asText()).isEqualTo(tagged.toString());
        assertThat(data.get("likeCount").asInt()).isZero();
        assertThat(data.get("likedByMe").asBoolean()).isFalse();

        assertThat(jdbc.queryForList("SELECT url FROM post_images WHERE post_id = ? ORDER BY display_order",
                String.class, postId)).containsExactly(PUBLIC_BASE + "/" + key1, PUBLIC_BASE + "/" + key2);
        assertThat(count("SELECT COUNT(*) FROM post_tags WHERE post_id = ?", postId)).isEqualTo(1);

        // The single-post endpoint returns the same aggregate
        mvc.perform(get("/api/v1/posts/{id}", postId).with(as(tagged)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.imageUrls.length()").value(2))
                .andExpect(jsonPath("$.data.taggedUsers[0].id").value(tagged.toString()))
                .andExpect(jsonPath("$.data.game.id").value(gameId.toString()));
    }

    @Test
    void createPostWithoutOptionalFieldsHasNoGameImagesOrTags() throws Exception {
        UUID author = user();
        mvc.perform(post("/api/v1/posts").with(as(author))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"caption\":\"just text\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.game").doesNotExist())
                .andExpect(jsonPath("$.data.imageUrls.length()").value(0))
                .andExpect(jsonPath("$.data.taggedUsers.length()").value(0));
    }

    @Test
    void createPostRejectsImageKeyOfAnotherUserAndPersistsNothing() throws Exception {
        UUID author = user();
        UUID other = user();
        String body = toJson(Map.of("caption", "stolen", "imageKeys", List.of("uploads/" + other + "/a.jpg")));

        mvc.perform(post("/api/v1/posts").with(as(author))
                        .contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_IMAGE_KEY"));

        assertThat(count("SELECT COUNT(*) FROM posts WHERE author_id = ?", author)).isZero();
    }

    @Test
    void createPostWithUnknownGameIs404() throws Exception {
        UUID author = user();
        mvc.perform(post("/api/v1/posts").with(as(author))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(Map.of("gameId", UUID.randomUUID()))))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("GAME_NOT_FOUND"));
    }

    @Test
    void createPostValidatesCaptionLength() throws Exception {
        UUID author = user();
        mvc.perform(post("/api/v1/posts").with(as(author))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(Map.of("caption", "x".repeat(2001)))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }

    @Test
    void postsApiRequiresAuthentication() throws Exception {
        mvc.perform(get("/api/v1/feed")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/feed").header("Authorization", "Bearer not-a-jwt"))
                .andExpect(status().isUnauthorized());
    }

    // -------------------------------------------------------------------------
    // Feed
    // -------------------------------------------------------------------------

    @Test
    void feedShowsOwnAndFriendsPostsNewestFirstWithPaging() throws Exception {
        UUID me = user();
        UUID friend = user();
        UUID stranger = user();
        friends(me, friend);
        Instant base = Instant.now().minus(1, ChronoUnit.HOURS);
        UUID mine = seedPost(me, base);
        UUID friendOld = seedPost(friend, base.plusSeconds(10));
        UUID friendNew = seedPost(friend, base.plusSeconds(20));
        seedPost(stranger, base.plusSeconds(30));
        UUID deleted = seedPost(friend, base.plusSeconds(40));
        jdbc.update("UPDATE posts SET deleted_at = now() WHERE id = ?", deleted);
        jdbc.update("INSERT INTO post_likes (post_id, user_id) VALUES (?, ?)", friendOld, me);

        JsonNode page1 = json(mvc.perform(get("/api/v1/feed").with(as(me))
                        .param("page", "0").param("size", "2"))
                .andExpect(status().isOk()).andReturn());
        assertThat(ids(page1)).containsExactly(friendNew, friendOld);
        assertThat(page1.get("data").get(1).get("likedByMe").asBoolean()).isTrue();
        assertThat(page1.get("data").get(0).get("likedByMe").asBoolean()).isFalse();
        assertThat(page1.get("meta").get("page").asInt()).isEqualTo(1);
        assertThat(page1.get("meta").get("total").asLong()).isEqualTo(3);
        assertThat(page1.get("meta").get("hasMore").asBoolean()).isTrue();

        JsonNode page2 = json(mvc.perform(get("/api/v1/feed").with(as(me))
                        .param("page", "1").param("size", "2"))
                .andExpect(status().isOk()).andReturn());
        assertThat(ids(page2)).containsExactly(mine);
        assertThat(page2.get("meta").get("hasMore").asBoolean()).isFalse();

        JsonNode beyond = json(mvc.perform(get("/api/v1/feed").with(as(me))
                        .param("page", "5").param("size", "2"))
                .andExpect(status().isOk()).andReturn());
        assertThat(beyond.get("data")).isEmpty();
        assertThat(beyond.get("meta").get("total").asLong()).isEqualTo(3);
    }

    @Test
    void feedAcceptsAccessTokenCookieAndHidesBlockedFriendsPosts() throws Exception {
        UUID me = user();
        UUID friend = user();
        friends(friend, me);
        UUID friendPost = seedPost(friend, Instant.now());
        String token = jwtUtil.generateAccessToken(me, 0);

        mvc.perform(get("/api/v1/feed").cookie(new Cookie("access_token", token)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items[0].kind").value("post"))
                .andExpect(jsonPath("$.data.items[0].post.id").value(friendPost.toString()));

        block(friend, me);
        mvc.perform(get("/api/v1/feed").cookie(new Cookie("access_token", token)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items.length()").value(0))
                .andExpect(jsonPath("$.data.hasMore").value(false));
    }

    @Test
    void userPostsListsAuthorsActivePostsAndIs404WhenBlocked() throws Exception {
        UUID viewer = user();
        UUID author = user();
        UUID older = seedPost(author, Instant.now().minusSeconds(60));
        UUID newer = seedPost(author, Instant.now());
        UUID gone = seedPost(author, Instant.now().plusSeconds(1));
        jdbc.update("UPDATE posts SET deleted_at = now() WHERE id = ?", gone);

        JsonNode page = json(mvc.perform(get("/api/v1/users/{id}/posts", author).with(as(viewer)))
                .andExpect(status().isOk()).andReturn());
        assertThat(ids(page)).containsExactly(newer, older);

        block(viewer, author);
        mvc.perform(get("/api/v1/users/{id}/posts", author).with(as(viewer)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("USER_NOT_FOUND"));
    }

    // -------------------------------------------------------------------------
    // Single post
    // -------------------------------------------------------------------------

    @Test
    void getPostIs404WhenMissingDeletedBlockedOrAuthorDeleted() throws Exception {
        UUID viewer = user();
        UUID author = user();
        UUID postId = seedPost(author, Instant.now());

        mvc.perform(get("/api/v1/posts/{id}", UUID.randomUUID()).with(as(viewer)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("POST_NOT_FOUND"));

        block(author, viewer);
        mvc.perform(get("/api/v1/posts/{id}", postId).with(as(viewer)))
                .andExpect(status().isNotFound());
        jdbc.update("DELETE FROM blocked_users WHERE blocker_id = ?", author);
        mvc.perform(get("/api/v1/posts/{id}", postId).with(as(viewer))).andExpect(status().isOk());

        softDeleteUser(author);
        mvc.perform(get("/api/v1/posts/{id}", postId).with(as(viewer)))
                .andExpect(status().isNotFound());
    }

    // -------------------------------------------------------------------------
    // Likes
    // -------------------------------------------------------------------------

    @Test
    void likeIsIdempotentNotifiesAuthorOnceAndUnlikeNeverGoesNegative() throws Exception {
        UUID author = user();
        UUID fan = user();
        UUID postId = seedPost(author, Instant.now());

        mvc.perform(post("/api/v1/posts/{id}/like", postId).with(as(fan))).andExpect(status().isNoContent());
        mvc.perform(post("/api/v1/posts/{id}/like", postId).with(as(fan))).andExpect(status().isNoContent());

        assertThat(likeCount(postId)).isEqualTo(1);
        assertThat(count("SELECT COUNT(*) FROM post_likes WHERE post_id = ?", postId)).isEqualTo(1);
        assertThat(count("SELECT COUNT(*) FROM notifications WHERE recipient_id = ? AND type = 'POST_LIKE'"
                + " AND actor_id = ? AND reference_id = ?", author, fan, postId)).isEqualTo(1);
        mvc.perform(get("/api/v1/posts/{id}", postId).with(as(fan)))
                .andExpect(jsonPath("$.data.likedByMe").value(true))
                .andExpect(jsonPath("$.data.likeCount").value(1));

        mvc.perform(delete("/api/v1/posts/{id}/like", postId).with(as(fan))).andExpect(status().isNoContent());
        mvc.perform(delete("/api/v1/posts/{id}/like", postId).with(as(fan))).andExpect(status().isNoContent());
        assertThat(likeCount(postId)).isZero();
        mvc.perform(get("/api/v1/posts/{id}", postId).with(as(fan)))
                .andExpect(jsonPath("$.data.likedByMe").value(false));
    }

    @Test
    void likingOwnPostCountsButDoesNotNotify() throws Exception {
        UUID author = user();
        UUID postId = seedPost(author, Instant.now());

        mvc.perform(post("/api/v1/posts/{id}/like", postId).with(as(author))).andExpect(status().isNoContent());

        assertThat(likeCount(postId)).isEqualTo(1);
        assertThat(count("SELECT COUNT(*) FROM notifications WHERE recipient_id = ?", author)).isZero();
    }

    @Test
    void likingPostOfBlockedOrBlockingAuthorIs404AndChangesNothing() throws Exception {
        UUID author = user();
        UUID fan = user();
        UUID postId = seedPost(author, Instant.now());
        block(fan, author);

        mvc.perform(post("/api/v1/posts/{id}/like", postId).with(as(fan)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("POST_NOT_FOUND"));
        assertThat(likeCount(postId)).isZero();
    }

    // -------------------------------------------------------------------------
    // Comments
    // -------------------------------------------------------------------------

    @Test
    void commentsAreCountedNotifiedListedOldestFirstAndFilteredForViewer() throws Exception {
        UUID author = user();
        UUID alice = user();
        UUID troll = user();
        UUID postId = seedPost(author, Instant.now());

        UUID first = UUID.fromString(json(mvc.perform(post("/api/v1/posts/{id}/comments", postId).with(as(alice))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"body\":\"first!\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.authorId").value(alice.toString()))
                .andExpect(jsonPath("$.data.body").value("first!"))
                .andReturn()).get("data").get("id").asText());
        mvc.perform(post("/api/v1/posts/{id}/comments", postId).with(as(troll))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"body\":\"meh\"}"))
                .andExpect(status().isCreated());
        // Author commenting on their own post: counted, but no self-notification
        mvc.perform(post("/api/v1/posts/{id}/comments", postId).with(as(author))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"body\":\"thanks\"}"))
                .andExpect(status().isCreated());

        assertThat(count("SELECT comment_count FROM posts WHERE id = ?", postId)).isEqualTo(3);
        assertThat(count("SELECT COUNT(*) FROM notifications WHERE recipient_id = ? AND type = 'POST_COMMENT'",
                author)).isEqualTo(2);

        JsonNode all = json(mvc.perform(get("/api/v1/posts/{id}/comments", postId).with(as(author)))
                .andExpect(status().isOk()).andReturn());
        assertThat(all.get("data")).extracting(n -> n.get("body").asText()).containsExactly("first!", "meh", "thanks");
        assertThat(all.get("data").get(0).get("id").asText()).isEqualTo(first.toString());

        // Alice blocked the troll: she no longer sees the troll's comment
        block(alice, troll);
        JsonNode filtered = json(mvc.perform(get("/api/v1/posts/{id}/comments", postId).with(as(alice))
                        .param("page", "0").param("size", "10"))
                .andExpect(status().isOk()).andReturn());
        assertThat(filtered.get("data")).extracting(n -> n.get("body").asText()).containsExactly("first!", "thanks");
        assertThat(filtered.get("meta").get("total").asLong()).isEqualTo(2);
    }

    @Test
    void commentValidationAndVisibility() throws Exception {
        UUID author = user();
        UUID other = user();
        UUID postId = seedPost(author, Instant.now());

        mvc.perform(post("/api/v1/posts/{id}/comments", postId).with(as(other))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"body\":\"  \"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));

        block(author, other);
        mvc.perform(post("/api/v1/posts/{id}/comments", postId).with(as(other))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"body\":\"hi\"}"))
                .andExpect(status().isNotFound());
        mvc.perform(get("/api/v1/posts/{id}/comments", postId).with(as(other)))
                .andExpect(status().isNotFound());
        assertThat(count("SELECT comment_count FROM posts WHERE id = ?", postId)).isZero();
    }

    // -------------------------------------------------------------------------
    // Delete
    // -------------------------------------------------------------------------

    @Test
    void onlyAuthorCanSoftDeleteAndDeletedPostDisappears() throws Exception {
        UUID author = user();
        UUID other = user();
        UUID postId = seedPost(author, Instant.now());

        mvc.perform(delete("/api/v1/posts/{id}", postId).with(as(other)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("FORBIDDEN"));

        mvc.perform(delete("/api/v1/posts/{id}", postId).with(as(author))).andExpect(status().isNoContent());
        assertThat(count("SELECT COUNT(*) FROM posts WHERE id = ? AND deleted_at IS NOT NULL", postId))
                .isEqualTo(1); // soft delete: the row is kept

        mvc.perform(get("/api/v1/posts/{id}", postId).with(as(author))).andExpect(status().isNotFound());
        mvc.perform(delete("/api/v1/posts/{id}", postId).with(as(author))).andExpect(status().isNotFound());
        mvc.perform(post("/api/v1/posts/{id}/like", postId).with(as(other))).andExpect(status().isNotFound());
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private UUID seedPost(UUID author, Instant createdAt) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO posts (id, author_id, caption, created_at) VALUES (?, ?, ?, ?)",
                id, author, "post " + id, ts(createdAt));
        return id;
    }

    private int likeCount(UUID postId) {
        return count("SELECT like_count FROM posts WHERE id = ?", postId);
    }

    private static List<UUID> ids(JsonNode page) {
        List<UUID> out = new ArrayList<>();
        page.get("data").forEach(n -> out.add(UUID.fromString(n.get("id").asText())));
        return out;
    }
}
