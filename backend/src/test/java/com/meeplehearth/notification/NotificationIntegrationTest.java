package com.meeplehearth.notification;

import com.fasterxml.jackson.databind.JsonNode;
import com.meeplehearth.notification.entity.Notification.NotificationType;
import com.meeplehearth.notification.service.NotificationService;
import com.meeplehearth.support.auth.AuthWebIntegrationTest;
import com.meeplehearth.user.entity.User;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Notifications persisted by the real service and read back through the HTTP API. */
class NotificationIntegrationTest extends AuthWebIntegrationTest {

    @Autowired private NotificationService notificationService;

    @Test
    void notificationsAreListedNewestFirstAndOnlyToTheirRecipient() throws Exception {
        User me = persistUser(true);
        User friend = persistUser(true);
        UUID postId = UUID.randomUUID();
        notificationService.send(me.getId(), NotificationType.FRIEND_REQUEST, friend.getId(), friend.getId(), "USER");
        Thread.sleep(5);
        notificationService.send(me.getId(), NotificationType.POST_LIKE, friend.getId(), postId, "POST");
        notificationService.send(friend.getId(), NotificationType.FRIEND_ACCEPTED, me.getId(), me.getId(), "USER");
        entityManager.flush();

        // Cursor shape (default)
        JsonNode cursorPage = body(mockMvc.perform(get("/api/v1/notifications").cookie(accessCookie(me)))
                .andExpect(status().isOk())
                .andReturn()).get("data");
        assertThat(cursorPage.get("items")).hasSize(2);
        assertThat(cursorPage.get("hasMore").asBoolean()).isFalse();
        JsonNode newest = cursorPage.at("/items/0");
        assertThat(newest.get("type").asText()).isEqualTo("POST_LIKE");
        assertThat(newest.at("/actor/id").asText()).isEqualTo(friend.getId().toString());
        assertThat(newest.get("referenceId").asText()).isEqualTo(postId.toString());
        assertThat(newest.get("referenceType").asText()).isEqualTo("POST");
        assertThat(newest.get("title").asText()).isEqualTo("New Like");
        assertThat(newest.at("/data/path").asText()).isEqualTo("/posts/" + postId);
        assertThat(newest.get("read").asBoolean()).isFalse();
        assertThat(newest.get("createdAt").isNull()).isFalse();
        assertThat(cursorPage.at("/items/1/type").asText()).isEqualTo("FRIEND_REQUEST");

        // Legacy page/size parameters keep the {data, meta} shape
        JsonNode page = body(mockMvc.perform(get("/api/v1/notifications").cookie(accessCookie(me))
                        .param("page", "0"))
                .andExpect(status().isOk())
                .andReturn());
        assertThat(page.at("/meta/total").asLong()).isEqualTo(2);
        assertThat(page.at("/meta/page").asInt()).isEqualTo(1);
        assertThat(page.at("/data/0/type").asText()).isEqualTo("POST_LIKE");

        JsonNode paged = body(mockMvc.perform(get("/api/v1/notifications").cookie(accessCookie(me))
                        .param("page", "1").param("size", "1"))
                .andReturn());
        assertThat(paged.at("/data/0/type").asText()).isEqualTo("FRIEND_REQUEST");
        assertThat(paged.at("/meta/page").asInt()).isEqualTo(2);
        assertThat(paged.at("/meta/hasMore").asBoolean()).isFalse();
    }

    @Test
    void markAllReadClearsOnlyTheCallersUnreadCount() throws Exception {
        User me = persistUser(true);
        User other = persistUser(true);
        notificationService.send(me.getId(), NotificationType.EVENT_INVITE, other.getId(), UUID.randomUUID(), "EVENT");
        notificationService.send(me.getId(), NotificationType.EVENT_RSVP, other.getId(), UUID.randomUUID(), "EVENT");
        notificationService.send(other.getId(), NotificationType.MATCH_FOUND, null, UUID.randomUUID(), "MATCH");
        // Each request normally runs in its own transaction; drop the entities this one still holds
        entityManager.flush();
        entityManager.clear();

        mockMvc.perform(get("/api/v1/notifications/unread-count").cookie(accessCookie(me)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.count").value(2));

        mockMvc.perform(put("/api/v1/notifications/read-all").cookie(accessCookie(me)))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/v1/notifications/unread-count").cookie(accessCookie(me)))
                .andExpect(jsonPath("$.data.count").value(0));
        mockMvc.perform(get("/api/v1/notifications").cookie(accessCookie(me)))
                .andExpect(jsonPath("$.data.items[0].read").value(true))
                .andExpect(jsonPath("$.data.items[1].read").value(true));
        mockMvc.perform(get("/api/v1/notifications/unread-count").cookie(accessCookie(other)))
                .andExpect(jsonPath("$.data.count").value(1));
    }

    @Test
    void notificationEndpointsRequireAuthentication() throws Exception {
        mockMvc.perform(get("/api/v1/notifications")).andExpect(status().isUnauthorized());
        mockMvc.perform(get("/api/v1/notifications/unread-count")).andExpect(status().isUnauthorized());
        mockMvc.perform(put("/api/v1/notifications/read-all")).andExpect(status().isUnauthorized());
    }
}
