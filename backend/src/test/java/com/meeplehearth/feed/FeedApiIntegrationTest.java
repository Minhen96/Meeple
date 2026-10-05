package com.meeplehearth.feed;

import com.fasterxml.jackson.databind.JsonNode;
import com.meeplehearth.common.event.ActivityRecordedEvent;
import com.meeplehearth.common.event.UserHardDeletedEvent;
import com.meeplehearth.support.social.ApiIntegrationTestBase;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.MediaType;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** The cursor feed end to end: union of posts and activities, keyset paging, cache, hydration rules. */
class FeedApiIntegrationTest extends ApiIntegrationTestBase {

    @Autowired private StringRedisTemplate redis;
    @Autowired private ApplicationEventPublisher publisher;
    @Autowired private TransactionTemplate transactionTemplate;

    // -------------------------------------------------------------------------
    // Union, order, paging
    // -------------------------------------------------------------------------

    @Test
    void feedMergesOwnAndFriendsPostsAndActivitiesNewestFirstAndPagesWithCursor() throws Exception {
        UUID me = user();
        UUID friend = user();
        UUID stranger = user();
        friends(friend, me);
        UUID gameId = game();
        Instant base = Instant.now().minus(1, ChronoUnit.HOURS);

        UUID myPost = seedPost(me, base);
        UUID friendActivity = seedActivity(friend, "collection_add", "{\"gameId\":\"" + gameId + "\"}",
                base.plusSeconds(10));
        UUID friendPost = seedPost(friend, base.plusSeconds(20));
        seedPost(stranger, base.plusSeconds(30));
        seedActivity(stranger, "collection_add", "{\"gameId\":\"" + gameId + "\"}", base.plusSeconds(35));
        UUID deletedPost = seedPost(friend, base.plusSeconds(40));
        jdbc.update("UPDATE posts SET deleted_at = now() WHERE id = ?", deletedPost);
        UUID deletedActivity = seedActivity(friend, "collection_add", "{\"gameId\":\"" + gameId + "\"}",
                base.plusSeconds(45));
        jdbc.update("UPDATE activity_events SET deleted_at = now() WHERE id = ?", deletedActivity);

        JsonNode page1 = feed(me, null, 2);
        assertThat(kindsAndIds(page1)).containsExactly("post:" + friendPost, "activity:" + friendActivity);
        assertThat(page1.get("hasMore").asBoolean()).isTrue();
        JsonNode activity = page1.get("items").get(1).get("activity");
        assertThat(activity.get("type").asText()).isEqualTo("collection_add");
        assertThat(activity.get("user").get("id").asText()).isEqualTo(friend.toString());
        assertThat(activity.get("user").get("deleted").asBoolean()).isFalse();
        assertThat(activity.get("data").get("gameName").asText()).isEqualTo("IT Game");
        assertThat(page1.get("items").get(1).get("createdAt").asText()).isNotBlank();
        assertThat(page1.get("items").get(0).has("activity")).isFalse();

        // A newer post arriving between pages neither shifts nor duplicates the next page
        seedPost(friend, Instant.now());
        JsonNode page2 = feed(me, page1.get("nextCursor").asText(), 2);
        assertThat(kindsAndIds(page2)).containsExactly("post:" + myPost);
        assertThat(page2.get("hasMore").asBoolean()).isFalse();
        assertThat(page2.get("nextCursor").isNull()).isTrue();
    }

    @Test
    void itemsWithTheSameTimestampAreNeitherSkippedNorRepeatedAcrossPages() throws Exception {
        UUID me = user();
        Instant same = Instant.now().minus(5, ChronoUnit.MINUTES).truncatedTo(ChronoUnit.SECONDS);
        List<UUID> posts = new ArrayList<>();
        for (int i = 0; i < 5; i++) {
            posts.add(seedPost(me, same));
        }

        List<String> seen = new ArrayList<>();
        String cursor = null;
        do {
            JsonNode page = feed(me, cursor, 2);
            seen.addAll(kindsAndIds(page));
            cursor = page.get("nextCursor").isNull() ? null : page.get("nextCursor").asText();
        } while (cursor != null);

        assertThat(seen).hasSize(5).doesNotHaveDuplicates()
                .containsExactlyInAnyOrderElementsOf(posts.stream().map(id -> "post:" + id).toList());
    }

    @Test
    void bareIsoCursorMeansStrictlyOlderAndGarbageCursorIs400() throws Exception {
        UUID me = user();
        Instant t = Instant.now().minus(10, ChronoUnit.MINUTES).truncatedTo(ChronoUnit.SECONDS);
        UUID older = seedPost(me, t.minusSeconds(1));
        seedPost(me, t);

        assertThat(kindsAndIds(feed(me, t.toString(), 20))).containsExactly("post:" + older);

        mvc.perform(get("/api/v1/feed").param("cursor", "not a cursor!").with(as(me)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_CURSOR"));
    }

    @Test
    void feedRequiresAuthentication() throws Exception {
        mvc.perform(get("/api/v1/feed")).andExpect(status().isUnauthorized());
    }

    // -------------------------------------------------------------------------
    // Cache
    // -------------------------------------------------------------------------

    @Test
    void firstPageIsCachedSixtySecondsButOwnNewPostShowsImmediately() throws Exception {
        UUID me = user();
        UUID friend = user();
        friends(me, friend);
        UUID first = seedPost(friend, Instant.now().minusSeconds(60));

        assertThat(kindsAndIds(feed(me, null, 20))).containsExactly("post:" + first);
        Long ttl = redis.getExpire("feed:" + me + ":first");
        assertThat(ttl).isBetween(1L, 60L);

        // A friend's post written behind the API's back is not visible until the entry expires…
        UUID late = seedPost(friend, Instant.now().minusSeconds(30));
        assertThat(kindsAndIds(feed(me, null, 20))).containsExactly("post:" + first);

        // …but my own post through the API invalidates my first page after commit
        JsonNode created = json(mvc.perform(post("/api/v1/posts").with(as(me))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"caption\":\"mine\"}"))
                .andExpect(status().isCreated()).andReturn()).get("data");
        assertThat(kindsAndIds(feed(me, null, 20)))
                .containsExactly("post:" + created.get("id").asText(), "post:" + late, "post:" + first);
    }

    @Test
    void cachedPageIsStillHydratedLiveForLikesDeletesAndBlocks() throws Exception {
        UUID me = user();
        UUID friend = user();
        UUID other = user();
        friends(me, friend);
        friends(me, other);
        UUID friendPost = seedPost(friend, Instant.now().minusSeconds(20));
        UUID otherPost = seedPost(other, Instant.now().minusSeconds(10));
        assertThat(kindsAndIds(feed(me, null, 20))).hasSize(2);

        mvc.perform(post("/api/v1/posts/{id}/like", friendPost).with(as(me))).andExpect(status().isNoContent());
        mvc.perform(post("/api/v1/posts/{id}/bookmark", friendPost).with(as(me))).andExpect(status().isNoContent());
        jdbc.update("UPDATE posts SET deleted_at = now() WHERE id = ?", otherPost);

        JsonNode page = feed(me, null, 20);
        assertThat(kindsAndIds(page)).containsExactly("post:" + friendPost);
        JsonNode post = page.get("items").get(0).get("post");
        assertThat(post.get("likedByMe").asBoolean()).isTrue();
        assertThat(post.get("isBookmarked").asBoolean()).isTrue();
        assertThat(post.get("likeCount").asInt()).isEqualTo(1);

        block(friend, me);
        assertThat(kindsAndIds(feed(me, null, 20))).isEmpty();
    }

    @Test
    void differentLimitBypassesTheCachedSkeleton() throws Exception {
        UUID me = user();
        seedPost(me, Instant.now().minusSeconds(30));
        seedPost(me, Instant.now().minusSeconds(20));
        assertThat(kindsAndIds(feed(me, null, 1))).hasSize(1);
        assertThat(kindsAndIds(feed(me, null, 2))).hasSize(2);
    }

    // -------------------------------------------------------------------------
    // Activity hydration
    // -------------------------------------------------------------------------

    @Test
    void eventActivitiesShowOnlyEventsTheViewerCanStillSee() throws Exception {
        UUID me = user();
        UUID friend = user();
        friends(me, friend);
        UUID gameId = game();
        UUID publicEvent = seedEvent(friend, "Board night", "PUBLIC", gameId);
        UUID inviteOnly = seedEvent(friend, "Secret night", "INVITE_ONLY", null);
        UUID cancelled = seedEvent(friend, "Called off", "FRIENDS", null);
        jdbc.update("UPDATE events SET status = 'CANCELLED' WHERE id = ?", cancelled);

        Instant base = Instant.now().minusSeconds(100);
        UUID visible = seedActivity(friend, "event_created", "{\"eventId\":\"" + publicEvent + "\"}", base);
        seedActivity(friend, "event_created", "{\"eventId\":\"" + inviteOnly + "\"}", base.plusSeconds(1));
        seedActivity(friend, "event_joined", "{\"eventId\":\"" + cancelled + "\"}", base.plusSeconds(2));
        seedActivity(friend, "collection_add", "{\"gameId\":\"" + UUID.randomUUID() + "\"}", base.plusSeconds(3));
        seedActivity(friend, "collection_add", "{\"gameId\":\"not-a-uuid\"}", base.plusSeconds(4));

        // Hidden, cancelled, unknown-game and malformed activities are all dropped
        JsonNode page = feed(me, null, 20);
        assertThat(kindsAndIds(page)).containsExactly("activity:" + visible);

        JsonNode data = page.get("items").get(0).get("activity").get("data");
        assertThat(data.get("eventTitle").asText()).isEqualTo("Board night");
        assertThat(data.get("eventScheduledAt").asText()).isNotBlank();
        assertThat(data.get("gameId").asText()).isEqualTo(gameId.toString());
        assertThat(data.get("gameName").asText()).isEqualTo("IT Game");
    }

    // -------------------------------------------------------------------------
    // ActivityRecordedEvent listener
    // -------------------------------------------------------------------------

    @Test
    void activityIsRecordedOnlyAfterThePublishingTransactionCommits() {
        UUID me = user();
        UUID gameId = game();

        transactionTemplate.executeWithoutResult(status -> {
            publisher.publishEvent(new ActivityRecordedEvent(me, ActivityRecordedEvent.COLLECTION_ADD,
                    Map.of("gameId", gameId), Instant.now()));
            assertThat(activities(me)).isZero(); // nothing before commit
        });
        assertThat(activities(me)).isEqualTo(1);
        assertThat(string("SELECT data ->> 'gameId' FROM activity_events WHERE user_id = ?", me))
                .isEqualTo(gameId.toString());

        transactionTemplate.executeWithoutResult(status -> {
            publisher.publishEvent(new ActivityRecordedEvent(me, ActivityRecordedEvent.EVENT_JOINED,
                    Map.of("eventId", UUID.randomUUID()), Instant.now()));
            status.setRollbackOnly();
        });
        assertThat(activities(me)).isEqualTo(1);
    }

    @Test
    void activityPublishedOutsideATransactionIsRecordedAndDuplicatesUnknownTypesAndDeletedUsersAreIgnored() {
        UUID me = user();
        UUID ghost = user();
        softDeleteUser(ghost);
        UUID gameId = game();

        publisher.publishEvent(new ActivityRecordedEvent(me, "collection_add", Map.of("gameId", gameId.toString()), null));
        // Same game again within 24h (owned toggled off and on): recorded once
        publisher.publishEvent(new ActivityRecordedEvent(me, "collection_add", Map.of("gameId", gameId), Instant.now()));
        publisher.publishEvent(new ActivityRecordedEvent(me, "post_liked", Map.of(), Instant.now()));
        publisher.publishEvent(new ActivityRecordedEvent(ghost, "collection_add", Map.of("gameId", gameId), null));
        publisher.publishEvent(new ActivityRecordedEvent(UUID.randomUUID(), "event_created", Map.of(), null));

        assertThat(activities(me)).isEqualTo(1);
        assertThat(activities(ghost)).isZero();
    }

    @Test
    void hardDeleteRemovesTheUsersActivitiesAndPosts() {
        UUID me = user();
        seedActivity(me, "collection_add", "{}", Instant.now());
        UUID postId = seedPost(me, Instant.now());

        publisher.publishEvent(new UserHardDeletedEvent(me));

        assertThat(activities(me)).isZero();
        assertThat(count("SELECT COUNT(*) FROM posts WHERE id = ?", postId)).isZero();
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private JsonNode feed(UUID viewer, String cursor, int limit) throws Exception {
        var request = get("/api/v1/feed").param("limit", String.valueOf(limit)).with(as(viewer));
        if (cursor != null) {
            request = request.param("cursor", cursor);
        }
        return json(mvc.perform(request).andExpect(status().isOk()).andReturn()).get("data");
    }

    private static List<String> kindsAndIds(JsonNode page) {
        List<String> out = new ArrayList<>();
        page.get("items").forEach(item -> {
            String kind = item.get("kind").asText();
            out.add(kind + ":" + item.get(kind).get("id").asText());
        });
        return out;
    }

    private UUID seedPost(UUID author, Instant createdAt) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO posts (id, author_id, caption, created_at) VALUES (?, ?, ?, ?)",
                id, author, "post " + id, ts(createdAt));
        return id;
    }

    private UUID seedActivity(UUID userId, String type, String json, Instant createdAt) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO activity_events (id, user_id, type, data, created_at) VALUES (?, ?, ?, ?::jsonb, ?)",
                id, userId, type, json, ts(createdAt));
        return id;
    }

    private UUID seedEvent(UUID host, String title, String visibility, UUID gameId) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO events (id, host_id, title, scheduled_at, visibility, status, game_id)"
                        + " VALUES (?, ?, ?, ?, ?, 'OPEN', ?)",
                id, host, title, ts(Instant.now().plus(3, ChronoUnit.DAYS)), visibility, gameId);
        return id;
    }

    private int activities(UUID userId) {
        return count("SELECT COUNT(*) FROM activity_events WHERE user_id = ?", userId);
    }
}
