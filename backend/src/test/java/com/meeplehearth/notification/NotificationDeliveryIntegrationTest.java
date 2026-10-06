package com.meeplehearth.notification;

import com.google.firebase.messaging.BatchResponse;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.MessagingErrorCode;
import com.google.firebase.messaging.SendResponse;
import com.meeplehearth.common.event.UserHardDeletedEvent;
import com.meeplehearth.common.event.UserSoftDeletedEvent;
import com.meeplehearth.config.WebSocketConfig;
import com.meeplehearth.notification.dto.NotificationWsPayload;
import com.meeplehearth.notification.entity.Notification.NotificationType;
import com.meeplehearth.notification.presence.WebSocketPresenceListener;
import com.meeplehearth.notification.service.NotificationService;
import com.meeplehearth.support.social.ApiIntegrationTestBase;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;

import java.time.Duration;
import java.time.LocalTime;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.awaitility.Awaitility.await;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.after;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.reset;
import static org.mockito.Mockito.timeout;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * The {@code send} pipeline end to end with real Postgres and Redis; only FirebaseMessaging is
 * mocked (so FCM counts as configured) and the STOMP template is spied on.
 */
class NotificationDeliveryIntegrationTest extends ApiIntegrationTestBase {

    @MockitoBean private FirebaseMessaging firebaseMessaging;
    @MockitoSpyBean private SimpMessagingTemplate messagingTemplate;

    @Autowired private NotificationService notificationService;
    @Autowired private StringRedisTemplate redis;
    @Autowired private ApplicationEventPublisher events;

    private final List<String> redisKeys = new ArrayList<>();

    @BeforeEach
    void acceptAllPushes() throws Exception {
        reset(firebaseMessaging);
        clearInvocations(messagingTemplate);
        when(firebaseMessaging.sendEach(anyList())).thenAnswer(inv -> batch(((List<?>) inv.getArgument(0)).size()));
    }

    @AfterEach
    void clearRedis() {
        if (!redisKeys.isEmpty()) redis.delete(redisKeys);
        redisKeys.clear();
    }

    private UUID recipient() {
        UUID id = user();
        redisKeys.add("notif:unread:" + id);
        redisKeys.add(WebSocketPresenceListener.key(id));
        return id;
    }

    private void device(UUID userId, String token) {
        jdbc.update("INSERT INTO user_fcm_tokens (user_id, fcm_token, platform) VALUES (?, ?, 'android')", userId, token);
    }

    // -------------------------------------------------------------------------

    @Test
    void offlineRecipientGetsWebSocketFramePushAndCounter() throws Exception {
        UUID me = recipient();
        UUID actor = user();
        jdbc.update("UPDATE users SET display_name = 'Bo' WHERE id = ?", actor);
        device(me, "dev-a-" + me);
        device(me, "dev-b-" + me);
        UUID postId = UUID.randomUUID();

        notificationService.send(me, NotificationType.POST_COMMENT, actor, postId, "POST");

        ArgumentCaptor<Object> frame = ArgumentCaptor.forClass(Object.class);
        verify(messagingTemplate).convertAndSendToUser(eq(me.toString()), eq(WebSocketConfig.USER_NOTIFICATION_QUEUE),
                frame.capture());
        NotificationWsPayload payload = (NotificationWsPayload) frame.getValue();
        assertThat(payload.unreadCount()).isEqualTo(1);
        assertThat(payload.notification().title()).isEqualTo("New Comment");
        assertThat(payload.notification().body()).isEqualTo("Bo commented on your post");
        assertThat(payload.notification().data()).containsEntry("path", "/posts/" + postId);
        assertThat(payload.notification().actor().displayName()).isEqualTo("Bo");
        assertThat(redis.opsForValue().get("notif:unread:" + me)).isEqualTo("1");

        @SuppressWarnings("unchecked")
        ArgumentCaptor<List<Message>> sent = ArgumentCaptor.forClass(List.class);
        verify(firebaseMessaging, timeout(5000)).sendEach(sent.capture());
        assertThat(sent.getValue()).hasSize(2);
        await().atMost(Duration.ofSeconds(5)).until(() ->
                count("SELECT COUNT(*) FROM notifications WHERE recipient_id = ? AND is_pushed", me) == 1);

        // A second notification: the counter increments from the cached value
        notificationService.send(me, NotificationType.POST_TAG, actor, postId, "POST");
        assertThat(redis.opsForValue().get("notif:unread:" + me)).isEqualTo("2");
    }

    @Test
    void onlineRecipientGetsNoPush() throws Exception {
        UUID me = recipient();
        device(me, "dev-online-" + me);
        // Another instance holds a live session of the recipient
        redis.opsForZSet().add(WebSocketPresenceListener.key(me), "other-instance",
                System.currentTimeMillis() + Duration.ofSeconds(30).toMillis());

        notificationService.send(me, NotificationType.MATCH_FOUND, null, UUID.randomUUID(), "MATCH_GROUP");

        verify(messagingTemplate).convertAndSendToUser(eq(me.toString()), any(), any(Object.class));
        verify(firebaseMessaging, after(500).never()).sendEach(anyList());
    }

    @Test
    void preferencesOffStillSaveTheRowButSkipChannels() throws Exception {
        UUID me = recipient();
        device(me, "dev-pref-" + me);
        jdbc.update("INSERT INTO notification_preferences (user_id, type, in_app_enabled, push_enabled)"
                + " VALUES (?, 'POST_TAG', FALSE, FALSE), (?, 'POST_COMMENT', TRUE, FALSE)", me, me);
        UUID actor = user();

        notificationService.send(me, NotificationType.POST_TAG, actor, UUID.randomUUID(), "POST");
        assertThat(count("SELECT COUNT(*) FROM notifications WHERE recipient_id = ? AND type = 'POST_TAG' AND read", me))
                .isEqualTo(1);
        verify(messagingTemplate, never()).convertAndSendToUser(eq(me.toString()), any(), any(Object.class));

        // In-app on, push off: WebSocket only
        notificationService.send(me, NotificationType.POST_COMMENT, actor, UUID.randomUUID(), "POST");
        verify(messagingTemplate).convertAndSendToUser(eq(me.toString()), any(), any(Object.class));
        verify(firebaseMessaging, after(500).never()).sendEach(anyList());
        // The in-app-disabled row never counted as unread
        assertThat(redis.opsForValue().get("notif:unread:" + me)).isEqualTo("1");
    }

    @Test
    void quietHoursSuppressWebSocketAndPushButCountTheNotification() throws Exception {
        UUID me = recipient();
        device(me, "dev-quiet-" + me);
        LocalTime now = LocalTime.now(ZoneOffset.UTC).truncatedTo(ChronoUnit.MINUTES);
        jdbc.update("INSERT INTO notification_settings (user_id, quiet_hours_enabled, quiet_hours_start,"
                        + " quiet_hours_end, timezone) VALUES (?, TRUE, ?::time, ?::time, 'UTC')",
                me, now.minusHours(1).toString(), now.plusHours(1).toString());

        notificationService.send(me, NotificationType.FRIEND_REQUEST, user(), UUID.randomUUID(), "FRIEND_REQUEST");

        assertThat(count("SELECT COUNT(*) FROM notifications WHERE recipient_id = ? AND NOT read", me)).isEqualTo(1);
        verify(messagingTemplate, never()).convertAndSendToUser(eq(me.toString()), any(), any(Object.class));
        verify(firebaseMessaging, after(500).never()).sendEach(anyList());
        mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                        .get("/api/v1/notifications/unread-count").with(as(me)))
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers
                        .jsonPath("$.data.count").value(1));

        // Outside the window delivery resumes
        jdbc.update("UPDATE notification_settings SET quiet_hours_start = ?::time, quiet_hours_end = ?::time"
                + " WHERE user_id = ?", now.plusHours(2).toString(), now.plusHours(3).toString(), me);
        notificationService.send(me, NotificationType.FRIEND_REQUEST, user(), UUID.randomUUID(), "FRIEND_REQUEST");
        verify(messagingTemplate).convertAndSendToUser(eq(me.toString()), any(), any(Object.class));
        verify(firebaseMessaging, timeout(5000)).sendEach(anyList());
    }

    @Test
    void staleTokensAreDeletedAndHealthyOnesKept() throws Exception {
        UUID me = recipient();
        String good = "good-" + me;
        String gone = "gone-" + me;
        String bad = "bad-" + me;
        device(me, good);
        device(me, gone);
        device(me, bad);
        when(firebaseMessaging.sendEach(anyList())).thenAnswer(inv -> {
            List<Message> messages = inv.getArgument(0);
            List<SendResponse> responses = new ArrayList<>();
            // Rows come back newest first; map by position to the tokens actually sent
            List<String> order = jdbc.queryForList(
                    "SELECT fcm_token FROM user_fcm_tokens WHERE user_id = ? ORDER BY updated_at DESC", String.class, me);
            for (int i = 0; i < messages.size(); i++) {
                String token = order.get(i);
                if (token.equals(gone)) responses.add(failure(MessagingErrorCode.UNREGISTERED));
                else if (token.equals(bad)) responses.add(failure(MessagingErrorCode.INVALID_ARGUMENT));
                else responses.add(success());
            }
            return batch(responses);
        });

        notificationService.send(me, NotificationType.EVENT_REMINDER, null, UUID.randomUUID(), "EVENT",
                Map.of("eventTitle", "Catan Night"));

        await().atMost(Duration.ofSeconds(5)).until(() ->
                count("SELECT COUNT(*) FROM user_fcm_tokens WHERE user_id = ?", me) == 1);
        assertThat(string("SELECT fcm_token FROM user_fcm_tokens WHERE user_id = ?", me)).isEqualTo(good);
        assertThat(string("SELECT body FROM notifications WHERE recipient_id = ?", me))
                .isEqualTo("Catan Night starts in 24 hours");
    }

    @Test
    void transientFcmFailureKeepsTokensAndDoesNotMarkPushed() throws Exception {
        UUID me = recipient();
        device(me, "flaky-" + me);
        when(firebaseMessaging.sendEach(anyList())).thenAnswer(inv -> batch(List.of(failure(MessagingErrorCode.UNAVAILABLE))));

        notificationService.send(me, NotificationType.MATCH_FOUND, null, UUID.randomUUID(), "MATCH_GROUP");

        verify(firebaseMessaging, timeout(5000)).sendEach(anyList());
        assertThat(count("SELECT COUNT(*) FROM user_fcm_tokens WHERE user_id = ?", me)).isEqualTo(1);
        assertThat(count("SELECT COUNT(*) FROM notifications WHERE recipient_id = ? AND is_pushed", me)).isZero();
    }

    @Test
    void blockedOrDeletedRecipientsGetNothing() {
        UUID me = recipient();
        UUID blocker = user();
        block(me, blocker);
        notificationService.send(me, NotificationType.POST_LIKE, blocker, UUID.randomUUID(), "POST");
        notificationService.send(blocker, NotificationType.POST_LIKE, me, UUID.randomUUID(), "POST");

        UUID gone = user();
        softDeleteUser(gone);
        notificationService.send(gone, NotificationType.MATCH_FOUND, null, UUID.randomUUID(), "MATCH_GROUP");
        notificationService.send(UUID.randomUUID(), NotificationType.MATCH_FOUND, null, null, null);
        notificationService.send(null, NotificationType.MATCH_FOUND, null, null, null);

        assertThat(count("SELECT COUNT(*) FROM notifications WHERE recipient_id IN (?, ?, ?)", me, blocker, gone))
                .isZero();
        verify(messagingTemplate, never()).convertAndSendToUser(any(), any(), any(Object.class));
    }

    @Test
    void likesOnAPostAreBatchedIntoOneNotificationPerHour() {
        UUID author = recipient();
        UUID post = UUID.randomUUID();
        UUID a = user();
        UUID b = user();
        UUID c = user();
        jdbc.update("UPDATE users SET display_name = 'Cy' WHERE id = ?", c);

        notificationService.send(author, NotificationType.POST_LIKE, a, post, "POST");
        notificationService.send(author, NotificationType.POST_LIKE, b, post, "POST");
        notificationService.send(author, NotificationType.POST_LIKE, b, post, "POST"); // unlike + like again
        notificationService.send(author, NotificationType.POST_LIKE, c, post, "POST");

        assertThat(count("SELECT COUNT(*) FROM notifications WHERE recipient_id = ? AND type = 'POST_LIKE'", author))
                .isEqualTo(1);
        assertThat(string("SELECT body FROM notifications WHERE recipient_id = ?", author))
                .isEqualTo("Cy and 2 others liked your post");
        assertThat(string("SELECT data->>'count' FROM notifications WHERE recipient_id = ?", author)).isEqualTo("3");
        assertThat(string("SELECT actor_id::text FROM notifications WHERE recipient_id = ?", author)).isEqualTo(c.toString());
        // Only the first like produced a real-time frame and counted as unread
        verify(messagingTemplate).convertAndSendToUser(eq(author.toString()), any(), any(Object.class));
        assertThat(redis.opsForValue().get("notif:unread:" + author)).isEqualTo("1");

        // An hour later the next like starts a new notification
        jdbc.update("UPDATE notifications SET created_at = now() - interval '61 minutes' WHERE recipient_id = ?", author);
        notificationService.send(author, NotificationType.POST_LIKE, a, post, "POST");
        assertThat(count("SELECT COUNT(*) FROM notifications WHERE recipient_id = ? AND type = 'POST_LIKE'", author))
                .isEqualTo(2);

        // Another post is batched separately
        notificationService.send(author, NotificationType.POST_LIKE, a, UUID.randomUUID(), "POST");
        assertThat(count("SELECT COUNT(*) FROM notifications WHERE recipient_id = ?", author)).isEqualTo(3);
    }

    @Test
    void messagesResolveEventGameAndMatchNamesInTheRecipientsLanguage() {
        UUID me = recipient();
        UUID host = user();
        jdbc.update("UPDATE users SET display_name = 'Host' WHERE id = ?", host);
        UUID event = UUID.randomUUID();
        jdbc.update("INSERT INTO events (id, host_id, title, scheduled_at) VALUES (?, ?, 'Catan Night', now())", event, host);
        UUID game = game();
        jdbc.update("UPDATE games SET name_en = 'Catan', name_zh = '卡坦岛' WHERE id = ?", game);
        UUID group = UUID.randomUUID();
        jdbc.update("INSERT INTO match_groups (id, game_id) VALUES (?, ?)", group, game);
        UUID friend = user();
        UUID friend2 = user();
        jdbc.update("INSERT INTO match_group_members (group_id, user_id) VALUES (?, ?), (?, ?), (?, ?)",
                group, me, group, friend, group, friend2);
        UUID note = UUID.randomUUID();
        jdbc.update("INSERT INTO game_rule_notes (id, game_id, user_id, content) VALUES (?, ?, ?, 'x')", note, game, me);

        notificationService.send(me, NotificationType.EVENT_INVITE, host, event, "EVENT");
        notificationService.send(me, NotificationType.MATCH_FOUND, null, group, "MATCH_GROUP");
        notificationService.send(me, NotificationType.RULE_NOTE_APPROVED, host, note, "RULE_NOTE");

        assertThat(string("SELECT body FROM notifications WHERE recipient_id = ? AND type = 'EVENT_INVITE'", me))
                .isEqualTo("Host invited you to Catan Night");
        assertThat(string("SELECT data->>'path' FROM notifications WHERE recipient_id = ? AND type = 'EVENT_INVITE'", me))
                .isEqualTo("/events/" + event);
        assertThat(string("SELECT body FROM notifications WHERE recipient_id = ? AND type = 'MATCH_FOUND'", me))
                .isEqualTo("2 friends want to play Catan");
        assertThat(string("SELECT data->>'path' FROM notifications WHERE recipient_id = ? AND type = 'RULE_NOTE_APPROVED'", me))
                .isEqualTo("/library/" + game);

        jdbc.update("UPDATE users SET preferred_language = 'zh-CN' WHERE id = ?", me);
        notificationService.send(me, NotificationType.RULE_NOTE_REJECTED, host, note, "RULE_NOTE");
        assertThat(string("SELECT title || '|' || body FROM notifications WHERE recipient_id = ? AND type = 'RULE_NOTE_REJECTED'", me))
                .isEqualTo("规则笔记未通过|你为 卡坦岛 提交的规则笔记未通过审核");
    }

    // -------------------------------------------------------------------------
    // Account deletion
    // -------------------------------------------------------------------------

    @Test
    void softDeleteRemovesNotificationsAndTokensHardDeleteAlsoTriggeredOnes() {
        UUID me = recipient();
        UUID other = recipient();
        device(me, "del-" + me);
        notificationService.send(me, NotificationType.MATCH_FOUND, null, UUID.randomUUID(), "MATCH_GROUP");
        notificationService.send(other, NotificationType.FRIEND_REQUEST, me, UUID.randomUUID(), "FRIEND_REQUEST");
        jdbc.update("INSERT INTO notification_preferences (user_id, type, in_app_enabled, push_enabled)"
                + " VALUES (?, 'POST_LIKE', FALSE, TRUE)", me);

        events.publishEvent(new UserSoftDeletedEvent(me));
        assertThat(count("SELECT COUNT(*) FROM notifications WHERE recipient_id = ?", me)).isZero();
        assertThat(count("SELECT COUNT(*) FROM user_fcm_tokens WHERE user_id = ?", me)).isZero();
        assertThat(redis.hasKey("notif:unread:" + me)).isFalse();
        assertThat(count("SELECT COUNT(*) FROM notifications WHERE recipient_id = ?", other)).isEqualTo(1);

        events.publishEvent(new UserHardDeletedEvent(me));
        assertThat(count("SELECT COUNT(*) FROM notifications WHERE actor_id = ?", me)).isZero();
        assertThat(count("SELECT COUNT(*) FROM notification_preferences WHERE user_id = ?", me)).isZero();
    }

    // -------------------------------------------------------------------------

    private static BatchResponse batch(int successes) {
        List<SendResponse> responses = new ArrayList<>();
        for (int i = 0; i < successes; i++) responses.add(success());
        return batch(responses);
    }

    private static BatchResponse batch(List<SendResponse> responses) {
        BatchResponse batch = mock(BatchResponse.class);
        when(batch.getResponses()).thenReturn(responses);
        return batch;
    }

    private static SendResponse success() {
        SendResponse r = mock(SendResponse.class);
        when(r.isSuccessful()).thenReturn(true);
        return r;
    }

    private static SendResponse failure(MessagingErrorCode code) {
        FirebaseMessagingException e = mock(FirebaseMessagingException.class);
        when(e.getMessagingErrorCode()).thenReturn(code);
        SendResponse r = mock(SendResponse.class);
        when(r.isSuccessful()).thenReturn(false);
        when(r.getException()).thenReturn(e);
        return r;
    }
}
