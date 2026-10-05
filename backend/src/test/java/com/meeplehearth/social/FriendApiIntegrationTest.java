package com.meeplehearth.social;

import com.fasterxml.jackson.databind.JsonNode;
import com.meeplehearth.social.service.FriendService;
import com.meeplehearth.support.social.ApiIntegrationTestBase;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.test.web.servlet.ResultActions;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Friend requests, friendship and blocking end to end: JWT → FriendController → FriendService → Postgres. */
class FriendApiIntegrationTest extends ApiIntegrationTestBase {

    @Autowired private FriendService friendService;
    @Autowired private StringRedisTemplate redis;

    // -------------------------------------------------------------------------
    // Request → accept → unfriend
    // -------------------------------------------------------------------------

    @Test
    void requestAcceptAndUnfriendLifecycle() throws Exception {
        UUID alice = user();
        UUID bob = user();

        UUID requestId = sendRequest(alice, bob)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("PENDING"))
                .andExpect(jsonPath("$.data.sender.id").value(alice.toString()))
                .andExpect(jsonPath("$.data.receiver.id").value(bob.toString()))
                .andReturn().getResponse().getContentAsString().transform(this::dataId);

        assertThat(count("SELECT COUNT(*) FROM notifications WHERE recipient_id = ? AND type = 'FRIEND_REQUEST'"
                + " AND actor_id = ? AND reference_id = ?", bob, alice, requestId)).isEqualTo(1);
        expectStatus(alice, bob, "PENDING_SENT", requestId);
        expectStatus(bob, alice, "PENDING_RECEIVED", requestId);

        // Receiver cannot cancel, sender cannot accept
        mvc.perform(delete("/api/v1/friend-requests/{id}", requestId).with(as(bob)))
                .andExpect(status().isForbidden());
        mvc.perform(post("/api/v1/friend-requests/{id}/accept", requestId).with(as(alice)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("FORBIDDEN"));

        mvc.perform(post("/api/v1/friend-requests/{id}/accept", requestId).with(as(bob)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("ACCEPTED"));

        expectStatus(alice, bob, "FRIENDS", requestId);
        expectStatus(bob, alice, "FRIENDS", requestId);
        assertThat(count("SELECT COUNT(*) FROM notifications WHERE type = 'FRIEND_ACCEPTED' AND reference_id = ?"
                + " AND recipient_id IN (?, ?)", requestId, alice, bob)).isEqualTo(2);
        mvc.perform(get("/api/v1/friends").with(as(alice)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.data[0].id").value(bob.toString()))
                .andExpect(jsonPath("$.meta.total").value(1));

        // Accepting twice is rejected
        mvc.perform(post("/api/v1/friend-requests/{id}/accept", requestId).with(as(bob)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("REQUEST_NOT_PENDING"));
        sendRequest(bob, alice)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("ALREADY_FRIENDS"));

        mvc.perform(delete("/api/v1/friends/{id}", alice).with(as(bob))).andExpect(status().isNoContent());
        expectStatus(alice, bob, "NONE", null);
        mvc.perform(get("/api/v1/friends").with(as(alice)))
                .andExpect(jsonPath("$.data.length()").value(0))
                .andExpect(jsonPath("$.meta.hasMore").value(false));
        mvc.perform(delete("/api/v1/friends/{id}", alice).with(as(bob)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("NOT_FRIENDS"));
    }

    @Test
    void sendRequestRejectsInvalidTargetsAndDuplicates() throws Exception {
        UUID alice = user();
        UUID bob = user();
        UUID ghost = user();
        softDeleteUser(ghost);

        sendRequest(alice, alice).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_TARGET"));
        sendRequest(alice, UUID.randomUUID()).andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("USER_NOT_FOUND"));
        sendRequest(alice, ghost).andExpect(status().isNotFound());

        sendRequest(alice, bob).andExpect(status().isOk());
        sendRequest(alice, bob).andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("REQUEST_PENDING"));
        // Bob asking Alice back is mutual intent: Alice's pending request is accepted
        sendRequest(bob, alice).andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("ACCEPTED"))
                .andExpect(jsonPath("$.data.sender.id").value(alice.toString()));

        assertThat(count("SELECT COUNT(*) FROM friend_requests WHERE sender_id IN (?, ?)", alice, bob)).isEqualTo(1);
        sendRequest(alice, bob).andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("ALREADY_FRIENDS"));
    }

    @Test
    void blockedUsersCannotSendRequestsInEitherDirection() throws Exception {
        UUID alice = user();
        UUID bob = user();
        block(bob, alice);

        sendRequest(alice, bob).andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("BLOCKED"));
        sendRequest(bob, alice).andExpect(status().isForbidden());
        assertThat(count("SELECT COUNT(*) FROM friend_requests WHERE sender_id IN (?, ?)", alice, bob)).isZero();
    }

    // -------------------------------------------------------------------------
    // Decline / re-send / cancel
    // -------------------------------------------------------------------------

    @Test
    void declineThenResendReusesTheSameRow() throws Exception {
        UUID alice = user();
        UUID bob = user();
        UUID requestId = dataId(sendRequest(alice, bob).andReturn().getResponse().getContentAsString());

        mvc.perform(post("/api/v1/friend-requests/{id}/decline", requestId).with(as(alice)))
                .andExpect(status().isForbidden());
        mvc.perform(post("/api/v1/friend-requests/{id}/decline", requestId).with(as(bob)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("DECLINED"));
        expectStatus(alice, bob, "NONE", null);
        mvc.perform(post("/api/v1/friend-requests/{id}/decline", requestId).with(as(bob)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("REQUEST_NOT_PENDING"));

        // Seven-day cooldown after a decline (FEATURES_COMPLETE 2.1)
        sendRequest(alice, bob).andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("REQUEST_COOLDOWN"));
        assertThat(redis.getExpire("fr:cooldown:" + alice + ":" + bob)).isGreaterThan(6L * 24 * 3600);

        redis.delete("fr:cooldown:" + alice + ":" + bob); // the cooldown elapsed
        sendRequest(alice, bob)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.id").value(requestId.toString()))
                .andExpect(jsonPath("$.data.status").value("PENDING"));
        assertThat(count("SELECT COUNT(*) FROM friend_requests WHERE sender_id = ? AND receiver_id = ?", alice, bob))
                .isEqualTo(1);
        assertThat(count("SELECT COUNT(*) FROM notifications WHERE recipient_id = ? AND type = 'FRIEND_REQUEST'", bob))
                .isEqualTo(2);
    }

    @Test
    void declinerCanLaterSendRequestAndBecomesTheSender() throws Exception {
        UUID alice = user();
        UUID bob = user();
        UUID requestId = dataId(sendRequest(alice, bob).andReturn().getResponse().getContentAsString());
        mvc.perform(post("/api/v1/friend-requests/{id}/decline", requestId).with(as(bob)))
                .andExpect(status().isOk());

        sendRequest(bob, alice)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.id").value(requestId.toString()))
                .andExpect(jsonPath("$.data.sender.id").value(bob.toString()))
                .andExpect(jsonPath("$.data.receiver.id").value(alice.toString()));

        expectStatus(alice, bob, "PENDING_RECEIVED", requestId);
        mvc.perform(post("/api/v1/friend-requests/{id}/accept", requestId).with(as(alice)))
                .andExpect(status().isOk());
        expectStatus(bob, alice, "FRIENDS", requestId);
    }

    @Test
    void pendingRequestIsNotAFriendship() throws Exception {
        UUID alice = user();
        UUID bob = user();
        sendRequest(alice, bob).andExpect(status().isOk());

        mvc.perform(delete("/api/v1/friends/{id}", bob).with(as(alice)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("NOT_FRIENDS"));
        assertThat(friendService.getFriendIds(alice)).isEmpty();

        friends(alice, user());
        assertThat(friendService.getFriendIds(alice)).hasSize(1);
        assertThat(count("SELECT COUNT(*) FROM friend_requests WHERE sender_id = ? AND receiver_id = ?", alice, bob))
                .isEqualTo(1); // the pending request is untouched
    }

    @Test
    void senderCanCancelPendingRequest() throws Exception {
        UUID alice = user();
        UUID bob = user();
        UUID requestId = dataId(sendRequest(alice, bob).andReturn().getResponse().getContentAsString());

        mvc.perform(delete("/api/v1/friend-requests/{id}", requestId).with(as(alice)))
                .andExpect(status().isNoContent());

        assertThat(count("SELECT COUNT(*) FROM friend_requests WHERE id = ?", requestId)).isZero();
        expectStatus(bob, alice, "NONE", null);
        mvc.perform(post("/api/v1/friend-requests/{id}/accept", requestId).with(as(bob)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("REQUEST_NOT_FOUND"));
    }

    // -------------------------------------------------------------------------
    // Pending lists
    // -------------------------------------------------------------------------

    @Test
    void receivedRequestsListsPendingRequestsWithSenderAndReceiver() throws Exception {
        UUID alice = user();
        UUID bob = user();
        UUID carol = user();
        sendRequest(alice, carol).andExpect(status().isOk());
        sendRequest(bob, carol).andExpect(status().isOk());

        JsonNode page = json(mvc.perform(get("/api/v1/friend-requests/received").with(as(carol)))
                .andExpect(status().isOk()).andReturn());
        assertThat(page.get("data")).hasSize(2);
        assertThat(page.get("data")).extracting(n -> n.get("sender").get("id").asText())
                .containsExactlyInAnyOrder(alice.toString(), bob.toString());
        assertThat(page.get("data")).allSatisfy(n ->
                assertThat(n.get("receiver").get("username").asText()).startsWith("it_"));
    }

    @Test
    void sentRequestsListsPendingRequestsWithSenderAndReceiver() throws Exception {
        UUID alice = user();
        UUID bob = user();
        sendRequest(alice, bob).andExpect(status().isOk());

        mvc.perform(get("/api/v1/friend-requests/sent").with(as(alice)).param("page", "0").param("size", "5"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.data[0].receiver.id").value(bob.toString()))
                .andExpect(jsonPath("$.data[0].sender.id").value(alice.toString()))
                .andExpect(jsonPath("$.meta.limit").value(5));
    }

    @Test
    void pendingListsAreEmptyWithoutRequests() throws Exception {
        UUID loner = user();
        mvc.perform(get("/api/v1/friend-requests/received").with(as(loner)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(0))
                .andExpect(jsonPath("$.meta.total").value(0));
        mvc.perform(get("/api/v1/friend-requests/sent").with(as(loner)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(0));
    }

    @Test
    void friendsListExcludesSoftDeletedFriendsAndPages() throws Exception {
        UUID me = user();
        UUID f1 = user();
        UUID f2 = user();
        UUID gone = user();
        friends(me, f1);
        friends(f2, me);
        friends(me, gone);
        softDeleteUser(gone);

        mvc.perform(get("/api/v1/friends").with(as(me)).param("page", "0").param("size", "1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.meta.total").value(2))
                .andExpect(jsonPath("$.meta.hasMore").value(true));
    }

    // -------------------------------------------------------------------------
    // Block / unblock
    // -------------------------------------------------------------------------

    @Test
    void blockRemovesFriendshipIsIdempotentAndUnblockRestoresNeutralState() throws Exception {
        UUID alice = user();
        UUID bob = user();
        friends(alice, bob);

        mvc.perform(post("/api/v1/users/{id}/block", bob).with(as(alice))).andExpect(status().isNoContent());
        mvc.perform(post("/api/v1/users/{id}/block", bob).with(as(alice))).andExpect(status().isNoContent());

        assertThat(count("SELECT COUNT(*) FROM blocked_users WHERE blocker_id = ? AND blocked_id = ?", alice, bob))
                .isEqualTo(1);
        assertThat(count("SELECT COUNT(*) FROM friend_requests WHERE sender_id IN (?, ?)", alice, bob)).isZero();
        expectStatus(alice, bob, "BLOCKED", null);
        expectStatus(bob, alice, "NONE", null); // the blocked side is not told about the block
        mvc.perform(get("/api/v1/friends").with(as(bob))).andExpect(jsonPath("$.data.length()").value(0));

        mvc.perform(delete("/api/v1/users/{id}/block", bob).with(as(alice))).andExpect(status().isNoContent());
        expectStatus(alice, bob, "NONE", null);
        // Unblocking someone who is not blocked is a no-op
        mvc.perform(delete("/api/v1/users/{id}/block", bob).with(as(alice))).andExpect(status().isNoContent());
        sendRequest(alice, bob).andExpect(status().isOk());
    }

    @Test
    void blockingYourselfIsRejected() throws Exception {
        UUID alice = user();
        mvc.perform(post("/api/v1/users/{id}/block", alice).with(as(alice)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_TARGET"));
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private ResultActions sendRequest(UUID from, UUID to) throws Exception {
        return mvc.perform(post("/api/v1/users/{id}/friend-request", to).with(as(from)));
    }

    private void expectStatus(UUID viewer, UUID target, String status, UUID requestId) throws Exception {
        ResultActions result = mvc.perform(get("/api/v1/users/{id}/friend-status", target).with(as(viewer)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value(status));
        if (requestId == null) {
            result.andExpect(jsonPath("$.data.requestId").doesNotExist());
        } else {
            result.andExpect(jsonPath("$.data.requestId").value(requestId.toString()));
        }
    }

    private UUID dataId(String body) {
        try {
            return UUID.fromString(objectMapper.readTree(body).get("data").get("id").asText());
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }
}
