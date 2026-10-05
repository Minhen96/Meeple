package com.meeplehearth.post;

import com.fasterxml.jackson.databind.JsonNode;
import com.meeplehearth.common.event.SessionPlayedEvent;
import com.meeplehearth.common.event.UserSoftDeletedEvent;
import com.meeplehearth.support.social.ApiIntegrationTestBase;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.MediaType;
import org.springframework.test.context.event.ApplicationEvents;
import org.springframework.test.context.event.RecordApplicationEvents;
import org.springframework.test.web.servlet.ResultActions;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.IntStream;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Post creation rules, editing, comments with mentions, bookmarks and event memories end to end. */
@RecordApplicationEvents
class PostFeaturesIntegrationTest extends ApiIntegrationTestBase {

    @Autowired private ApplicationEvents events;
    @Autowired private ApplicationEventPublisher publisher;

    // -------------------------------------------------------------------------
    // Create: tags, plays, notifications, validation
    // -------------------------------------------------------------------------

    @Test
    void creatingASessionPostTagsFriendsNotifiesThemAndPublishesTheSession() throws Exception {
        UUID author = user();
        UUID friend = user();
        UUID blocker = user();
        friends(author, friend);
        block(blocker, author); // blocked the author: silently dropped, no friendship needed
        UUID gameId = game();
        Instant playedAt = Instant.now().minus(2, ChronoUnit.HOURS).truncatedTo(ChronoUnit.SECONDS);

        JsonNode data = createPost(author, Map.of("caption", "Wingspan night", "gameId", gameId,
                "playedAt", playedAt.toString(), "taggedUserIds", List.of(friend, blocker, author)))
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString().transform(this::data);
        UUID postId = UUID.fromString(data.get("id").asText());

        assertThat(data.get("taggedUsers")).extracting(n -> n.get("id").asText())
                .containsExactly(friend.toString(), author.toString());
        assertThat(data.get("isBookmarked").asBoolean()).isFalse();
        assertThat(data.get("editedAt").isNull()).isTrue();
        assertThat(data.get("author").get("deleted").asBoolean()).isFalse();

        List<SessionPlayedEvent> sessions = events.stream(SessionPlayedEvent.class).toList();
        assertThat(sessions).hasSize(1);
        assertThat(sessions.get(0).userIds()).containsExactly(author, friend);
        assertThat(sessions.get(0).gameId()).isEqualTo(gameId);
        assertThat(sessions.get(0).playedAt()).isEqualTo(playedAt);
        assertThat(sessions.get(0).postId()).isEqualTo(postId);

        assertThat(notifications(friend, "POST_TAG")).isEqualTo(1);
        assertThat(string("SELECT data ->> 'gameName' FROM notifications WHERE recipient_id = ? AND type = 'POST_TAG'",
                friend)).isEqualTo("IT Game");
        assertThat(string("SELECT data ->> 'path' FROM notifications WHERE recipient_id = ? AND type = 'POST_TAG'",
                friend)).isEqualTo("/posts/" + postId);
        assertThat(notifications(author, "POST_TAG")).isZero();
        assertThat(notifications(blocker, "POST_TAG")).isZero();
    }

    @Test
    void postWithoutGameRecordsNoSessionAndTaggingANonFriendIsRejected() throws Exception {
        UUID author = user();
        UUID stranger = user();

        createPost(author, Map.of("caption", "just chatting")).andExpect(status().isCreated());
        assertThat(events.stream(SessionPlayedEvent.class)).isEmpty();

        createPost(author, Map.of("caption", "tag", "taggedUserIds", List.of(stranger)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("NOT_FRIENDS"));
        assertThat(count("SELECT COUNT(*) FROM posts WHERE author_id = ?", author)).isEqualTo(1);
    }

    @Test
    void createValidatesPlayedAtImageCountAndLocationLength() throws Exception {
        UUID author = user();
        createPost(author, Map.of("playedAt", Instant.now().plus(1, ChronoUnit.HOURS).toString()))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("PLAYED_AT_IN_FUTURE"));

        List<String> keys = IntStream.range(0, 11).mapToObj(i -> "uploads/" + author + "/" + i + ".webp").toList();
        createPost(author, Map.of("imageKeys", keys))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));

        createPost(author, Map.of("location", "x".repeat(101)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
        assertThat(count("SELECT COUNT(*) FROM posts WHERE author_id = ?", author)).isZero();
    }

    // -------------------------------------------------------------------------
    // Event memories
    // -------------------------------------------------------------------------

    @Test
    void hostAndAttendeesCanPostMemoriesListedByEventWithCursor() throws Exception {
        UUID host = user();
        UUID attendee = user();
        UUID outsider = user();
        UUID event = seedEvent(host, "PUBLIC");
        jdbc.update("INSERT INTO event_participants (event_id, user_id, status) VALUES (?, ?, 'ACCEPTED')",
                event, attendee);

        UUID p1 = postId(createPost(host, Map.of("caption", "setup", "eventId", event)));
        UUID p2 = postId(createPost(attendee, Map.of("caption", "winner", "eventId", event)));
        createPost(outsider, Map.of("eventId", event))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("NOT_PARTICIPANT"));
        createPost(host, Map.of("eventId", UUID.randomUUID()))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("EVENT_NOT_FOUND"));
        jdbc.update("UPDATE posts SET created_at = created_at - interval '1 minute' WHERE id = ?", p1);

        JsonNode page1 = json(mvc.perform(get("/api/v1/posts").param("eventId", event.toString())
                        .param("limit", "1").with(as(outsider)))
                .andExpect(status().isOk()).andReturn()).get("data");
        assertThat(page1.get("items").get(0).get("id").asText()).isEqualTo(p2.toString());
        assertThat(page1.get("items").get(0).get("eventId").asText()).isEqualTo(event.toString());
        assertThat(page1.get("hasMore").asBoolean()).isTrue();

        JsonNode page2 = json(mvc.perform(get("/api/v1/posts").param("eventId", event.toString())
                        .param("cursor", page1.get("nextCursor").asText()).with(as(outsider)))
                .andExpect(status().isOk()).andReturn()).get("data");
        assertThat(page2.get("items")).extracting(n -> n.get("id").asText()).containsExactly(p1.toString());
        assertThat(page2.get("hasMore").asBoolean()).isFalse();

        UUID hidden = seedEvent(host, "INVITE_ONLY");
        mvc.perform(get("/api/v1/posts").param("eventId", hidden.toString()).with(as(outsider)))
                .andExpect(status().isNotFound());
    }

    // -------------------------------------------------------------------------
    // Edit
    // -------------------------------------------------------------------------

    @Test
    void authorEditsWithin48hNewTagsAreNotifiedAndRecordedOnly() throws Exception {
        UUID author = user();
        UUID first = user();
        UUID second = user();
        friends(author, first);
        friends(second, author);
        UUID gameId = game();
        UUID postId = postId(createPost(author, Map.of("caption", "v1", "gameId", gameId,
                "taggedUserIds", List.of(first))));
        events.clear();

        Map<String, Object> body = new HashMap<>();
        body.put("caption", "v2");
        body.put("location", "");
        body.put("taggedUserIds", List.of(second));
        JsonNode updated = json(mvc.perform(put("/api/v1/posts/{id}", postId).with(as(author))
                        .contentType(MediaType.APPLICATION_JSON).content(toJson(body)))
                .andExpect(status().isOk()).andReturn()).get("data");

        assertThat(updated.get("caption").asText()).isEqualTo("v2");
        assertThat(updated.get("location").isNull()).isTrue();
        assertThat(updated.get("editedAt").isNull()).isFalse();
        assertThat(updated.get("game").get("id").asText()).isEqualTo(gameId.toString());
        assertThat(updated.get("taggedUsers")).extracting(n -> n.get("id").asText()).containsExactly(second.toString());
        assertThat(notifications(second, "POST_TAG")).isEqualTo(1);
        assertThat(notifications(first, "POST_TAG")).isEqualTo(1); // only from the original post
        List<SessionPlayedEvent> sessions = events.stream(SessionPlayedEvent.class).toList();
        assertThat(sessions).hasSize(1);
        assertThat(sessions.get(0).userIds()).containsExactly(second);

        mvc.perform(put("/api/v1/posts/{id}", postId).with(as(first))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"caption\":\"hijack\"}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("FORBIDDEN"));

        jdbc.update("UPDATE posts SET created_at = now() - interval '49 hours' WHERE id = ?", postId);
        mvc.perform(put("/api/v1/posts/{id}", postId).with(as(author))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"caption\":\"late\"}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("EDIT_WINDOW_EXPIRED"));
    }

    @Test
    void settingOrChangingTheGameRecordsTheSessionForEveryoneAndClearGameRemovesIt() throws Exception {
        UUID author = user();
        UUID friend = user();
        friends(author, friend);
        UUID gameA = game();
        UUID gameB = game();
        UUID postId = postId(createPost(author, Map.of("taggedUserIds", List.of(friend))));
        assertThat(events.stream(SessionPlayedEvent.class)).isEmpty();

        editPost(author, postId, Map.of("gameId", gameA)).andExpect(status().isOk());
        editPost(author, postId, Map.of("gameId", gameA)).andExpect(status().isOk()); // unchanged: nothing new
        editPost(author, postId, Map.of("gameId", gameB, "playedAt", Instant.now().minusSeconds(60).toString()))
                .andExpect(status().isOk());
        List<SessionPlayedEvent> sessions = events.stream(SessionPlayedEvent.class).toList();
        assertThat(sessions).extracting(SessionPlayedEvent::gameId).containsExactly(gameA, gameB);
        assertThat(sessions).allSatisfy(e -> assertThat(e.userIds()).containsExactly(author, friend));

        editPost(author, postId, Map.of("clearGame", true))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.game").doesNotExist());
        assertThat(events.stream(SessionPlayedEvent.class)).hasSize(2);
    }

    // -------------------------------------------------------------------------
    // Comments: edit, delete, mentions
    // -------------------------------------------------------------------------

    @Test
    void mentionsNotifyMentionedUsersExceptSelfPostAuthorBlockedAndUnknown() throws Exception {
        UUID author = user();
        UUID commenter = user();
        UUID mentioned = user();
        UUID blockedOne = user();
        block(blockedOne, commenter);
        UUID postId = seedPost(author);

        String body = "gg @" + username(mentioned) + " @" + username(commenter).toUpperCase() + " @"
                + username(author) + " @" + username(blockedOne) + " @nobody_here mail@" + username(mentioned);
        JsonNode comment = json(addComment(commenter, postId, body).andExpect(status().isCreated()).andReturn())
                .get("data");
        assertThat(comment.get("authorDisplayName").asText()).startsWith("IT ");
        assertThat(comment.get("editedAt").isNull()).isTrue();

        assertThat(notifications(mentioned, "COMMENT_MENTION")).isEqualTo(1);
        assertThat(string("SELECT data ->> 'commentId' FROM notifications WHERE recipient_id = ? AND type = 'COMMENT_MENTION'",
                mentioned)).isEqualTo(comment.get("id").asText());
        assertThat(notifications(commenter, "COMMENT_MENTION")).isZero();
        assertThat(notifications(author, "COMMENT_MENTION")).isZero();
        assertThat(notifications(author, "POST_COMMENT")).isEqualTo(1);
        assertThat(notifications(blockedOne, "COMMENT_MENTION")).isZero();
    }

    @Test
    void commentAuthorEditsWithin24hAndOnlyNewMentionsNotify() throws Exception {
        UUID author = user();
        UUID commenter = user();
        UUID a = user();
        UUID b = user();
        UUID postId = seedPost(author);
        UUID commentId = commentId(addComment(commenter, postId, "hi @" + username(a)));

        JsonNode edited = json(editComment(commenter, postId, commentId, "hi @" + username(a) + " and @" + username(b))
                .andExpect(status().isOk()).andReturn()).get("data");
        assertThat(edited.get("body").asText()).contains("and @");
        assertThat(edited.get("editedAt").isNull()).isFalse();
        assertThat(notifications(a, "COMMENT_MENTION")).isEqualTo(1);
        assertThat(notifications(b, "COMMENT_MENTION")).isEqualTo(1);

        editComment(author, postId, commentId, "not yours").andExpect(status().isForbidden());
        editComment(commenter, postId, UUID.randomUUID(), "missing")
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("COMMENT_NOT_FOUND"));
        editComment(commenter, postId, commentId, "x".repeat(501))
                .andExpect(status().isBadRequest());

        jdbc.update("UPDATE post_comments SET created_at = now() - interval '25 hours' WHERE id = ?", commentId);
        editComment(commenter, postId, commentId, "late")
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("EDIT_WINDOW_EXPIRED"));
    }

    @Test
    void commentsCanBeDeletedByTheirAuthorOrThePostAuthorOnly() throws Exception {
        UUID author = user();
        UUID commenter = user();
        UUID other = user();
        UUID postId = seedPost(author);
        UUID c1 = commentId(addComment(commenter, postId, "first"));
        UUID c2 = commentId(addComment(commenter, postId, "second"));
        assertThat(commentCount(postId)).isEqualTo(2);

        mvc.perform(delete("/api/v1/posts/{p}/comments/{c}", postId, c1).with(as(other)))
                .andExpect(status().isForbidden());
        mvc.perform(delete("/api/v1/posts/{p}/comments/{c}", postId, c1).with(as(commenter)))
                .andExpect(status().isNoContent());
        mvc.perform(delete("/api/v1/posts/{p}/comments/{c}", postId, c2).with(as(author)))
                .andExpect(status().isNoContent());
        mvc.perform(delete("/api/v1/posts/{p}/comments/{c}", postId, c2).with(as(author)))
                .andExpect(status().isNotFound());

        assertThat(commentCount(postId)).isZero();
        mvc.perform(get("/api/v1/posts/{id}/comments", postId).with(as(author)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(0));
    }

    // -------------------------------------------------------------------------
    // Bookmarks
    // -------------------------------------------------------------------------

    @Test
    void bookmarksAreIdempotentListedNewestFirstAndHideGonePosts() throws Exception {
        UUID me = user();
        UUID author = user();
        UUID blocked = user();
        UUID p1 = seedPost(author);
        UUID p2 = seedPost(author);
        UUID p3 = seedPost(blocked);

        for (UUID id : List.of(p1, p2, p2, p3)) {
            mvc.perform(post("/api/v1/posts/{id}/bookmark", id).with(as(me))).andExpect(status().isNoContent());
        }
        jdbc.update("UPDATE bookmarks SET saved_at = now() - interval '1 hour' WHERE post_id = ?", p1);
        assertThat(count("SELECT COUNT(*) FROM bookmarks WHERE user_id = ?", me)).isEqualTo(3);
        block(me, blocked);

        mvc.perform(get("/api/v1/posts/{id}", p2).with(as(me)))
                .andExpect(jsonPath("$.data.isBookmarked").value(true));

        JsonNode page1 = bookmarks(me, null, 1);
        assertThat(ids(page1)).containsExactly(p2);
        assertThat(page1.get("items").get(0).get("isBookmarked").asBoolean()).isTrue();
        JsonNode page2 = bookmarks(me, page1.get("nextCursor").asText(), 1);
        assertThat(ids(page2)).containsExactly(p1);
        assertThat(page2.get("hasMore").asBoolean()).isFalse();

        jdbc.update("UPDATE posts SET deleted_at = now() WHERE id = ?", p1);
        assertThat(ids(bookmarks(me, null, 20))).containsExactly(p2);

        mvc.perform(delete("/api/v1/posts/{id}/bookmark", p2).with(as(me))).andExpect(status().isNoContent());
        mvc.perform(delete("/api/v1/posts/{id}/bookmark", p2).with(as(me))).andExpect(status().isNoContent());
        assertThat(ids(bookmarks(me, null, 20))).isEmpty();

        mvc.perform(post("/api/v1/posts/{id}/bookmark", p3).with(as(me))).andExpect(status().isNotFound());
        mvc.perform(post("/api/v1/posts/{id}/bookmark", UUID.randomUUID()).with(as(me)))
                .andExpect(status().isNotFound());
    }

    @Test
    void softDeletingAnAccountRemovesItsBookmarks() throws Exception {
        UUID me = user();
        UUID postId = seedPost(user());
        mvc.perform(post("/api/v1/posts/{id}/bookmark", postId).with(as(me))).andExpect(status().isNoContent());

        publisher.publishEvent(new UserSoftDeletedEvent(me));

        assertThat(count("SELECT COUNT(*) FROM bookmarks WHERE user_id = ?", me)).isZero();
    }

    @Test
    void softDeletedTaggedUsersAreHiddenFromThePost() throws Exception {
        UUID author = user();
        UUID friend = user();
        friends(author, friend);
        UUID postId = postId(createPost(author, Map.of("taggedUserIds", List.of(friend))));
        softDeleteUser(friend);

        mvc.perform(get("/api/v1/posts/{id}", postId).with(as(author)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.taggedUsers.length()").value(0));
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private ResultActions createPost(UUID author, Map<String, ?> body) throws Exception {
        return mvc.perform(post("/api/v1/posts").with(as(author))
                .contentType(MediaType.APPLICATION_JSON).content(toJson(body)));
    }

    private ResultActions editPost(UUID author, UUID postId, Map<String, ?> body) throws Exception {
        return mvc.perform(put("/api/v1/posts/{id}", postId).with(as(author))
                .contentType(MediaType.APPLICATION_JSON).content(toJson(body)));
    }

    private ResultActions addComment(UUID user, UUID postId, String body) throws Exception {
        return mvc.perform(post("/api/v1/posts/{id}/comments", postId).with(as(user))
                .contentType(MediaType.APPLICATION_JSON).content(toJson(Map.of("body", body))));
    }

    private ResultActions editComment(UUID user, UUID postId, UUID commentId, String body) throws Exception {
        return mvc.perform(put("/api/v1/posts/{p}/comments/{c}", postId, commentId).with(as(user))
                .contentType(MediaType.APPLICATION_JSON).content(toJson(Map.of("body", body))));
    }

    private JsonNode bookmarks(UUID user, String cursor, int limit) throws Exception {
        var request = get("/api/v1/users/me/bookmarks").param("limit", String.valueOf(limit)).with(as(user));
        if (cursor != null) {
            request = request.param("cursor", cursor);
        }
        return json(mvc.perform(request).andExpect(status().isOk()).andReturn()).get("data");
    }

    private UUID postId(ResultActions result) throws Exception {
        return UUID.fromString(json(result.andExpect(status().isCreated()).andReturn()).get("data").get("id").asText());
    }

    private UUID commentId(ResultActions result) throws Exception {
        return postId(result);
    }

    private JsonNode data(String body) {
        try {
            return objectMapper.readTree(body).get("data");
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    private UUID seedPost(UUID author) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO posts (id, author_id, caption) VALUES (?, ?, 'seeded')", id, author);
        return id;
    }

    private UUID seedEvent(UUID host, String visibility) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO events (id, host_id, title, scheduled_at, visibility, status) VALUES (?, ?, 'Night', ?, ?, 'OPEN')",
                id, host, ts(Instant.now().minus(1, ChronoUnit.DAYS)), visibility);
        return id;
    }

    private String username(UUID userId) {
        return string("SELECT username FROM users WHERE id = ?", userId);
    }

    private int notifications(UUID recipient, String type) {
        return count("SELECT COUNT(*) FROM notifications WHERE recipient_id = ? AND type = ?", recipient, type);
    }

    private int commentCount(UUID postId) {
        return count("SELECT comment_count FROM posts WHERE id = ?", postId);
    }

    private static List<UUID> ids(JsonNode page) {
        List<UUID> out = new ArrayList<>();
        page.get("items").forEach(n -> out.add(UUID.fromString(n.get("id").asText())));
        return out;
    }
}
