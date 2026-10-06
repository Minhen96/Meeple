package com.meeplehearth.user;

import com.fasterxml.jackson.databind.JsonNode;
import com.meeplehearth.config.AppProperties;
import com.meeplehearth.event.service.EventLifecycleService;
import com.meeplehearth.user.dto.UserSummary;
import com.meeplehearth.user.job.AccountHardDeleteJob;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import software.amazon.awssdk.services.s3.model.DeleteObjectsRequest;
import software.amazon.awssdk.services.s3.model.ListObjectsV2Request;
import software.amazon.awssdk.services.s3.model.ListObjectsV2Response;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Hard delete anonymises instead of cascading (FEATURES_COMPLETE section 1.6, V60): hosted events
 * and comments survive as "Deleted User", upcoming events are cancelled first, and a NULL host
 * never widens who can see an event.
 */
class HardDeleteAnonymisationFeatureTest extends AccountFeatureTestBase {

    @Autowired AccountHardDeleteJob job;
    @Autowired EventLifecycleService lifecycle;
    @Autowired AppProperties appProperties;

    private final List<UUID> events = new ArrayList<>();

    @AfterEach
    void removeOrphanedEvents() {
        events.forEach(id -> jdbc.update("DELETE FROM events WHERE id = ?", id));
    }

    private UUID event(UUID host, String visibility, String status, Instant scheduledAt) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO events (id, host_id, title, scheduled_at, visibility, status) VALUES (?, ?, ?, ?, ?, ?)",
                id, host, visibility + " night", ts(scheduledAt), visibility, status);
        if (host != null) {
            participant(id, host, "ACCEPTED");
        }
        events.add(id);
        return id;
    }

    private void participant(UUID eventId, UUID userId, String status) {
        jdbc.update("INSERT INTO event_participants (event_id, user_id, status) VALUES (?, ?, ?)", eventId, userId, status);
    }

    private UUID post(UUID author) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO posts (id, author_id, caption) VALUES (?, ?, 'p')", id, author);
        return id;
    }

    private UUID comment(UUID postId, UUID author, String body) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO post_comments (id, post_id, author_id, body) VALUES (?, ?, ?, ?)", id, postId, author, body);
        jdbc.update("UPDATE posts SET comment_count = comment_count + 1 WHERE id = ?", postId);
        return id;
    }

    private void expire(UUID userId) {
        jdbc.update("UPDATE users SET deleted_at = ? WHERE id = ?", ts(Instant.now().minus(Duration.ofDays(31))), userId);
    }

    private void stubEmptyListings() {
        when(s3Client.listObjectsV2(any(ListObjectsV2Request.class)))
                .thenReturn(ListObjectsV2Response.builder().isTruncated(false).build());
    }

    @Test
    void hostedEventsAreKeptAsDeletedUserAndUpcomingOnesCancelled() throws Exception {
        UUID host = user();
        UUID going = user();
        UUID invited = user();
        UUID hostFriend = user();
        UUID stranger = user();
        friends(host, hostFriend);
        UUID upcoming = event(host, "PUBLIC", "OPEN", Instant.now().plus(Duration.ofDays(3)));
        participant(upcoming, going, "ACCEPTED");
        participant(upcoming, invited, "INVITED");
        UUID past = event(host, "PUBLIC", "COMPLETED", Instant.now().minus(Duration.ofDays(3)));
        participant(past, going, "ACCEPTED");
        UUID inviteOnly = event(host, "INVITE_ONLY", "COMPLETED", Instant.now().minus(Duration.ofDays(2)));
        participant(inviteOnly, going, "ACCEPTED");
        UUID friendsOnly = event(host, "FRIENDS", "COMPLETED", Instant.now().minus(Duration.ofDays(1)));
        participant(friendsOnly, going, "ACCEPTED");
        expire(host);
        stubEmptyListings();

        assertThat(job.purgeExpiredAccounts()).isGreaterThanOrEqualTo(1);

        assertThat(count("SELECT count(*) FROM users WHERE id = ?", host)).isZero();
        assertThat(count("SELECT count(*) FROM events WHERE id IN (?, ?, ?, ?) AND host_id IS NULL",
                upcoming, past, inviteOnly, friendsOnly)).isEqualTo(4);
        assertThat(string("SELECT status FROM events WHERE id = ?", upcoming)).isEqualTo("CANCELLED");
        assertThat(count("SELECT count(*) FROM events WHERE id = ? AND deleted_at IS NOT NULL", upcoming)).isEqualTo(1);
        assertThat(string("SELECT status FROM events WHERE id = ?", past)).isEqualTo("COMPLETED");
        // Only accepted participants hear about the cancellation, with no actor
        assertThat(count("SELECT count(*) FROM notifications WHERE recipient_id = ? AND type = 'EVENT_CANCELLED'"
                + " AND reference_id = ? AND actor_id IS NULL", going, upcoming)).isEqualTo(1);
        assertThat(count("SELECT count(*) FROM notifications WHERE recipient_id = ? AND type = 'EVENT_CANCELLED'",
                invited)).isZero();

        // The kept event shows its host as "Deleted User"
        JsonNode body = json(mvc.perform(get("/api/v1/events/{id}", past).with(as(going)))
                .andExpect(status().isOk()).andReturn()).get("data");
        assertThat(body.get("host").get("deleted").asBoolean()).isTrue();
        assertThat(body.get("host").get("id").asText()).isEqualTo(UserSummary.DELETED_USER_ID.toString());
        assertThat(body.get("host").get("username").isNull()).isTrue();
        assertThat(body.get("isHost").asBoolean()).isFalse();
        // Still visible to its public audience and listed in the participant's history
        mvc.perform(get("/api/v1/events/{id}", past).with(as(stranger))).andExpect(status().isOk());
        JsonNode history = json(mvc.perform(get("/api/v1/events").param("scope", "past").with(as(going)))
                .andExpect(status().isOk()).andReturn());
        assertThat(history.toString()).contains(past.toString(), inviteOnly.toString(), friendsOnly.toString());
        // The cancelled event is still shown (as cancelled) to the people who were going
        JsonNode cancelled = json(mvc.perform(get("/api/v1/events/{id}", upcoming).with(as(going)))
                .andExpect(status().isOk()).andReturn()).get("data");
        assertThat(cancelled.get("status").asText()).isEqualTo("CANCELLED");

        // A NULL host widens nothing: INVITE_ONLY stays participants-only ...
        mvc.perform(get("/api/v1/events/{id}", inviteOnly).with(as(going))).andExpect(status().isOk());
        mvc.perform(get("/api/v1/events/{id}", inviteOnly).with(as(stranger))).andExpect(status().isNotFound());
        // ... and FRIENDS events are left to their participants (the host's friends lose access)
        mvc.perform(get("/api/v1/events/{id}", friendsOnly).with(as(going))).andExpect(status().isOk());
        mvc.perform(get("/api/v1/events/{id}", friendsOnly).with(as(hostFriend))).andExpect(status().isNotFound());
        mvc.perform(get("/api/v1/events/{id}", friendsOnly).with(as(stranger))).andExpect(status().isNotFound());
        // Nobody can act as the host of an orphaned event
        mvc.perform(delete("/api/v1/events/{id}/participants/{u}", past, going).with(as(going)))
                .andExpect(status().is4xxClientError());
    }

    @Test
    void liveEventOfADeletedHostCompletesWithoutAHostNotification() {
        UUID attendee = user();
        UUID orphan = event(null, "PUBLIC", "OPEN", Instant.now().minus(Duration.ofHours(13)));
        participant(orphan, attendee, "ACCEPTED");

        assertThat(lifecycle.completeDueEvents(Instant.now())).isGreaterThanOrEqualTo(1);

        assertThat(string("SELECT status FROM events WHERE id = ?", orphan)).isEqualTo("COMPLETED");
        assertThat(count("SELECT count(*) FROM notifications WHERE reference_id = ? AND type = 'EVENT_COMPLETED'",
                orphan)).isZero();
    }

    @Test
    void commentsAreKeptAsDeletedUserAndTheDeletedUsersPostImagesLeaveStorage() throws Exception {
        UUID postAuthor = user();
        UUID leaver = user();
        UUID reader = user();
        UUID otherPost = post(postAuthor);
        UUID kept = comment(otherPost, leaver, "nice game");
        UUID leaversPost = post(leaver);
        String movedKey = "posts/" + leaversPost + "/0.webp";
        jdbc.update("INSERT INTO post_images (post_id, url, display_order) VALUES (?, ?, 0)",
                leaversPost, appProperties.getR2().getPublicUrl() + "/" + movedKey);
        expire(leaver);
        stubEmptyListings();

        job.purgeExpiredAccounts();

        assertThat(count("SELECT count(*) FROM post_comments WHERE id = ? AND author_id IS NULL", kept)).isEqualTo(1);
        assertThat(count("SELECT count(*) FROM posts WHERE id = ?", leaversPost)).isZero();
        verify(s3Client).deleteObjects(argThat((DeleteObjectsRequest r) ->
                r.delete().objects().stream().anyMatch(o -> o.key().equals(movedKey))));

        JsonNode item = json(mvc.perform(get("/api/v1/posts/{id}/comments", otherPost).with(as(reader)))
                .andExpect(status().isOk()).andReturn()).get("data").get("items").get(0);
        assertThat(item.get("id").asText()).isEqualTo(kept.toString());
        assertThat(item.get("author").get("deleted").asBoolean()).isTrue();
        assertThat(item.get("authorId").asText()).isEqualTo(UserSummary.DELETED_USER_ID.toString());
        assertThat(item.get("body").asText()).isEqualTo("nice game");

        // Nobody is the comment's author any more: the reader cannot delete it, the post author can
        mvc.perform(delete("/api/v1/posts/{p}/comments/{c}", otherPost, kept).with(as(reader)))
                .andExpect(status().isForbidden());
        mvc.perform(delete("/api/v1/posts/{p}/comments/{c}", otherPost, kept).with(as(postAuthor)))
                .andExpect(status().isNoContent());
    }

    @Test
    void softDeletedCommentAuthorShowsAsDeletedUser() throws Exception {
        UUID postAuthor = user();
        UUID leaver = user();
        UUID postId = post(postAuthor);
        comment(postId, leaver, "see you");
        softDeleteUser(leaver);

        JsonNode item = json(mvc.perform(get("/api/v1/posts/{id}/comments", postId).with(as(postAuthor)))
                .andExpect(status().isOk()).andReturn()).get("data").get("items").get(0);
        assertThat(item.get("author").get("id").asText()).isEqualTo(leaver.toString());
        assertThat(item.get("author").get("deleted").asBoolean()).isTrue();
        assertThat(item.get("authorUsername").isNull()).isTrue();
    }

    @Test
    void deletedParticipantLeavesLiveEventsAndTheirLikesAreReleased() throws Exception {
        UUID host = user();
        UUID leaver = user();
        UUID other = user();
        UUID full = event(host, "PUBLIC", "FULL", Instant.now().plus(Duration.ofDays(2)));
        jdbc.update("UPDATE events SET max_participants = 2 WHERE id = ?", full);
        participant(full, leaver, "ACCEPTED");
        UUID open = event(host, "FRIENDS", "OPEN", Instant.now().plus(Duration.ofDays(4)));
        participant(open, leaver, "ACCEPTED");
        participant(open, other, "ACCEPTED");
        UUID completed = event(host, "PUBLIC", "COMPLETED", Instant.now().minus(Duration.ofDays(2)));
        participant(completed, leaver, "ACCEPTED");

        UUID liked = post(host);
        jdbc.update("INSERT INTO post_likes (post_id, user_id) VALUES (?, ?), (?, ?)", liked, leaver, liked, other);
        jdbc.update("UPDATE posts SET like_count = 2 WHERE id = ?", liked);
        UUID drifted = post(other);
        jdbc.update("INSERT INTO post_likes (post_id, user_id) VALUES (?, ?)", drifted, leaver);
        UUID untouched = post(other);
        jdbc.update("UPDATE posts SET like_count = 5 WHERE id = ?", untouched);

        expire(leaver);
        stubEmptyListings();
        assertThat(job.purgeExpiredAccounts()).isGreaterThanOrEqualTo(1);

        assertThat(count("SELECT COUNT(*) FROM users WHERE id = ?", leaver)).isZero();
        assertThat(string("SELECT status FROM events WHERE id = ?", full)).isEqualTo("OPEN");
        assertThat(string("SELECT status FROM events WHERE id = ?", open)).isEqualTo("OPEN");
        assertThat(string("SELECT status FROM events WHERE id = ?", completed)).isEqualTo("COMPLETED");
        assertThat(count("SELECT COUNT(*) FROM event_participants WHERE event_id = ? AND status = 'ACCEPTED'", full))
                .isEqualTo(1);
        assertThat(count("SELECT like_count FROM posts WHERE id = ?", liked)).isEqualTo(1);
        assertThat(count("SELECT like_count FROM posts WHERE id = ?", drifted)).isZero();
        assertThat(count("SELECT like_count FROM posts WHERE id = ?", untouched)).isEqualTo(5);

        JsonNode detail = json(mvc.perform(get("/api/v1/events/" + full).with(as(other)))
                .andExpect(status().isOk()).andReturn()).get("data");
        assertThat(detail.get("participantCount").asInt()).isEqualTo(1);
        assertThat(detail.get("status").asText()).isEqualTo("OPEN");
    }
}
