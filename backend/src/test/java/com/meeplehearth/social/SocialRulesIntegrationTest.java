package com.meeplehearth.social;

import com.fasterxml.jackson.databind.JsonNode;
import com.meeplehearth.common.event.UserSoftDeletedEvent;
import com.meeplehearth.social.dto.SuggestedUser;
import com.meeplehearth.social.dto.UserSummaryWithStatus;
import com.meeplehearth.social.service.SocialQueryService;
import com.meeplehearth.support.social.ApiIntegrationTestBase;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.ApplicationEventPublisher;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** FEATURES_COMPLETE 2.1–2.3 rules added on top of the basic friend-request flow. */
class SocialRulesIntegrationTest extends ApiIntegrationTestBase {

    @Autowired private SocialQueryService socialQueryService;
    @Autowired private ApplicationEventPublisher publisher;

    @Test
    void atMostFiftyOutgoingRequestsMayBePending() throws Exception {
        UUID me = user();
        for (int i = 0; i < 50; i++) {
            jdbc.update("INSERT INTO friend_requests (sender_id, receiver_id, status) VALUES (?, ?, 'PENDING')",
                    me, user());
        }
        mvc.perform(post("/api/v1/users/{id}/friend-request", user()).with(as(me)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("PENDING_LIMIT"));
    }

    @Test
    void senderCancelsByTargetUser() throws Exception {
        UUID me = user();
        UUID target = user();
        mvc.perform(post("/api/v1/users/{id}/friend-request", target).with(as(me))).andExpect(status().isOk());

        mvc.perform(delete("/api/v1/users/{id}/friend-request", target).with(as(target)))
                .andExpect(status().isNotFound()); // the receiver has nothing to cancel
        mvc.perform(delete("/api/v1/users/{id}/friend-request", target).with(as(me)))
                .andExpect(status().isNoContent());
        mvc.perform(delete("/api/v1/users/{id}/friend-request", target).with(as(me)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("REQUEST_NOT_FOUND"));
        assertThat(count("SELECT COUNT(*) FROM friend_requests WHERE sender_id = ?", me)).isZero();
    }

    @Test
    void blockedListShowsOnlyUsersIBlockedNewestFirst() throws Exception {
        UUID me = user();
        UUID first = user();
        UUID second = user();
        UUID blocksMe = user();
        mvc.perform(post("/api/v1/users/{id}/block", first).with(as(me))).andExpect(status().isNoContent());
        jdbc.update("UPDATE blocked_users SET created_at = now() - interval '1 day' WHERE blocked_id = ?", first);
        mvc.perform(post("/api/v1/users/{id}/block", second).with(as(me))).andExpect(status().isNoContent());
        block(blocksMe, me);

        JsonNode list = json(mvc.perform(get("/api/v1/users/me/blocked").with(as(me)))
                .andExpect(status().isOk()).andReturn()).get("data");
        assertThat(list).extracting(n -> n.get("id").asText()).containsExactly(second.toString(), first.toString());
        assertThat(list.get(0).get("deleted").asBoolean()).isFalse();

        mvc.perform(post("/api/v1/users/{id}/block", UUID.randomUUID()).with(as(me)))
                .andExpect(status().isNotFound());
    }

    @Test
    void searchCarriesFriendshipStatusAndExcludesSelfBlockedAndDeleted() {
        String tag = "zq" + UUID.randomUUID().toString().substring(0, 6);
        UUID me = named(tag + "_me");
        UUID friend = named(tag + "_friend");
        UUID sent = named(tag + "_sent");
        UUID received = named(tag + "_recv");
        UUID declined = named(tag + "_declined");
        UUID stranger = named(tag + "_stranger");
        UUID blocked = named(tag + "_blocked");
        UUID deleted = named(tag + "_deleted");
        friends(me, friend);
        request(me, sent, "PENDING");
        request(received, me, "PENDING");
        request(me, declined, "DECLINED");
        block(blocked, me);
        softDeleteUser(deleted);

        List<UserSummaryWithStatus> results = socialQueryService.searchWithStatus(me, "  " + tag.toUpperCase() + " ", 20);

        assertThat(results).extracting(UserSummaryWithStatus::id)
                .containsExactlyInAnyOrder(friend, sent, received, declined, stranger);
        assertThat(results).filteredOn(r -> r.id().equals(friend)).extracting(UserSummaryWithStatus::friendshipStatus)
                .containsExactly("friends");
        assertThat(results).filteredOn(r -> r.id().equals(sent)).extracting(UserSummaryWithStatus::friendshipStatus)
                .containsExactly("pending_sent");
        assertThat(results).filteredOn(r -> r.id().equals(received)).extracting(UserSummaryWithStatus::friendshipStatus)
                .containsExactly("pending_received");
        assertThat(results).filteredOn(r -> r.id().equals(declined)).extracting(UserSummaryWithStatus::friendshipStatus)
                .containsExactly("none");

        // Exact username match ranks first; LIKE wildcards in the query are literal
        assertThat(socialQueryService.searchWithStatus(me, tag + "_stranger", 5)).extracting(UserSummaryWithStatus::id)
                .first().isEqualTo(stranger);
        assertThat(socialQueryService.searchWithStatus(me, "%", 5)).isEmpty();
        assertThat(socialQueryService.searchWithStatus(me, "   ", 5)).isEmpty();
        assertThat(socialQueryService.searchWithStatus(me, tag, 0, 2).meta().hasMore()).isTrue();
    }

    @Test
    void suggestionsRankByGameOverlapAndExcludeFriendsPendingBlockedAndDeleted() {
        UUID me = user();
        UUID g1 = game();
        UUID g2 = game();
        UUID g3 = game();
        own(me, g1, g2, g3);
        UUID two = user();
        own(two, g1, g2);
        UUID one = user();
        own(one, g3);
        UUID friend = user();
        own(friend, g1, g2, g3);
        friends(me, friend);
        UUID pending = user();
        own(pending, g1, g2, g3);
        request(pending, me, "PENDING");
        UUID blocker = user();
        own(blocker, g1);
        block(blocker, me);
        UUID gone = user();
        own(gone, g1);
        softDeleteUser(gone);
        UUID wishOnly = user();
        jdbc.update("INSERT INTO user_games (user_id, game_id, is_owned, is_favorited) VALUES (?, ?, false, true)",
                wishOnly, g1);

        List<SuggestedUser> suggestions = socialQueryService.suggestions(me, 10);

        assertThat(suggestions).extracting(SuggestedUser::id).startsWith(two, one)
                .doesNotContain(me, friend, pending, blocker, gone);
        assertThat(suggestions.get(0).sharedGames()).isEqualTo(2);
        assertThat(suggestions.get(1).sharedGames()).isEqualTo(1);
        assertThat(suggestions).hasSizeLessThanOrEqualTo(10);
        // Top-up users have no overlap
        assertThat(suggestions.subList(2, suggestions.size())).allSatisfy(s -> assertThat(s.sharedGames()).isZero());
    }

    @Test
    void suggestionsEndpointTopsUpForUsersWithoutACollection() throws Exception {
        UUID me = user();
        UUID newest = user();
        JsonNode list = json(mvc.perform(get("/api/v1/friends/suggestions").param("limit", "50").with(as(me)))
                .andExpect(status().isOk()).andReturn()).get("data");
        assertThat(list.size()).isBetween(1, 10);
        assertThat(list).extracting(n -> n.get("id").asText()).contains(newest.toString()).doesNotContain(me.toString());
    }

    @Test
    void softDeleteRemovesPendingRequestsButKeepsFriendships() {
        UUID me = user();
        UUID friend = user();
        UUID asked = user();
        UUID asker = user();
        friends(me, friend);
        request(me, asked, "PENDING");
        request(asker, me, "PENDING");

        publisher.publishEvent(new UserSoftDeletedEvent(me));

        assertThat(count("SELECT COUNT(*) FROM friend_requests WHERE status = 'PENDING' AND (sender_id = ? OR receiver_id = ?)",
                me, me)).isZero();
        assertThat(count("SELECT COUNT(*) FROM friend_requests WHERE status = 'ACCEPTED' AND sender_id = ?", me))
                .isEqualTo(1);
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private UUID named(String username) {
        UUID id = user();
        jdbc.update("UPDATE users SET username = ? WHERE id = ?", username.toLowerCase(), id);
        return id;
    }

    private void request(UUID from, UUID to, String status) {
        jdbc.update("INSERT INTO friend_requests (sender_id, receiver_id, status) VALUES (?, ?, ?)", from, to, status);
    }

    private void own(UUID userId, UUID... games) {
        for (UUID g : games) {
            jdbc.update("INSERT INTO user_games (user_id, game_id, is_owned) VALUES (?, ?, true)", userId, g);
        }
    }
}
