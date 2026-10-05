package com.meeplehearth.notification;

import com.meeplehearth.common.job.JobLock;
import com.meeplehearth.notification.job.NotificationCleanupJob;
import com.meeplehearth.notification.presence.WebSocketPresenceListener;
import com.meeplehearth.notification.repository.NotificationRepository;
import com.meeplehearth.notification.service.UnreadCounter;
import com.meeplehearth.support.social.ApiIntegrationTestBase;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.messaging.Message;
import org.springframework.messaging.simp.SimpMessageHeaderAccessor;
import org.springframework.messaging.simp.SimpMessageType;
import org.springframework.messaging.support.MessageBuilder;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.messaging.SessionConnectedEvent;
import org.springframework.web.socket.messaging.SessionDisconnectEvent;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/** Presence, the unread counter and the retention job against real Redis and Postgres. */
class NotificationRedisAndJobIntegrationTest extends ApiIntegrationTestBase {

    @Autowired private StringRedisTemplate redis;
    @Autowired private WebSocketPresenceListener presence;
    @Autowired private UnreadCounter counter;
    @Autowired private NotificationRepository notificationRepository;
    @Autowired private NotificationCleanupJob cleanupJob;
    @Autowired private JobLock jobLock;

    private final List<String> keys = new ArrayList<>();

    @AfterEach
    void clearRedis() {
        if (!keys.isEmpty()) redis.delete(keys);
        keys.clear();
    }

    private static Message<byte[]> connectedMessage(String sessionId) {
        SimpMessageHeaderAccessor accessor = SimpMessageHeaderAccessor.create(SimpMessageType.CONNECT_ACK);
        accessor.setSessionId(sessionId);
        return MessageBuilder.createMessage(new byte[0], accessor.getMessageHeaders());
    }

    @Test
    void presenceKeyLivesWhileAnySessionIsOpen() {
        UUID me = UUID.randomUUID();
        keys.add(WebSocketPresenceListener.key(me));
        UsernamePasswordAuthenticationToken principal = new UsernamePasswordAuthenticationToken(me.toString(), null);

        presence.onConnected(new SessionConnectedEvent(this, connectedMessage("s1-" + me), principal));
        presence.onConnected(new SessionConnectedEvent(this, connectedMessage("s2-" + me), principal));
        assertThat(presence.isOnline(me)).isTrue();
        Long ttl = redis.getExpire(WebSocketPresenceListener.key(me));
        assertThat(ttl).isBetween(1L, 30L);

        presence.onDisconnect(new SessionDisconnectEvent(this, connectedMessage("s1-" + me), "s1-" + me,
                CloseStatus.NORMAL, principal));
        assertThat(presence.isOnline(me)).isTrue();

        // Heartbeat restores an expired key while the session is open
        redis.delete(WebSocketPresenceListener.key(me));
        presence.refresh();
        assertThat(presence.isOnline(me)).isTrue();

        presence.onDisconnect(new SessionDisconnectEvent(this, connectedMessage("s2-" + me), "s2-" + me,
                CloseStatus.NORMAL, principal));
        assertThat(presence.isOnline(me)).isFalse();
        // Unknown or anonymous sessions are ignored
        presence.onDisconnect(new SessionDisconnectEvent(this, connectedMessage("nope"), "nope", CloseStatus.NORMAL));
        presence.onConnected(new SessionConnectedEvent(this, connectedMessage("anon")));
    }

    @Test
    void presenceTreatsRedisErrorsAsOffline() {
        StringRedisTemplate broken = mock(StringRedisTemplate.class);
        when(broken.hasKey(anyString())).thenThrow(new IllegalStateException("down"));
        @SuppressWarnings("unchecked")
        ValueOperations<String, String> ops = mock(ValueOperations.class);
        when(broken.opsForValue()).thenReturn(ops);
        org.mockito.Mockito.doThrow(new IllegalStateException("down")).when(ops)
                .set(anyString(), anyString(), any(Duration.class));
        when(broken.delete(anyString())).thenThrow(new IllegalStateException("down"));
        WebSocketPresenceListener listener = new WebSocketPresenceListener(broken);

        assertThat(listener.isOnline(UUID.randomUUID())).isFalse();
        listener.onConnected(new SessionConnectedEvent(this, connectedMessage("x"),
                new UsernamePasswordAuthenticationToken("u", null)));
        listener.refresh();
        listener.onDisconnect(new SessionDisconnectEvent(this, connectedMessage("x"), "x", CloseStatus.NORMAL));
    }

    @Test
    void unreadCounterFallsBackToTheDatabaseWhenRedisFails() {
        UUID me = user();
        jdbc.update("INSERT INTO notifications (recipient_id, type) VALUES (?, 'MATCH_FOUND'), (?, 'MATCH_FOUND')", me, me);
        StringRedisTemplate broken = mock(StringRedisTemplate.class);
        when(broken.opsForValue()).thenThrow(new IllegalStateException("down"));
        when(broken.execute(any(), anyList())).thenThrow(new IllegalStateException("down"));
        when(broken.delete(anyString())).thenThrow(new IllegalStateException("down"));
        UnreadCounter fallback = new UnreadCounter(broken, notificationRepository);

        assertThat(fallback.get(me)).isEqualTo(2);
        assertThat(fallback.increment(me)).isEqualTo(2);
        fallback.decrement(me);
        fallback.reset(me);
        fallback.evict(me);

        // Real Redis: a cold increment recomputes instead of starting from 1
        keys.add("notif:unread:" + me);
        redis.delete("notif:unread:" + me);
        assertThat(counter.increment(me)).isEqualTo(2);
        assertThat(counter.increment(me)).isEqualTo(3);
        counter.decrement(me);
        assertThat(counter.get(me)).isEqualTo(2);
        redis.opsForValue().set("notif:unread:" + me, "0");
        counter.decrement(me);
        assertThat(counter.get(me)).isZero();
    }

    @Test
    void cleanupDeletesExpiredAndLongSoftDeletedRowsUnderTheLock() {
        UUID me = user();
        jdbc.update("INSERT INTO notifications (recipient_id, type, created_at) VALUES (?, 'MATCH_FOUND', ?)",
                me, ts(Instant.now().minus(Duration.ofDays(91))));
        jdbc.update("INSERT INTO notifications (recipient_id, type, deleted_at) VALUES (?, 'MATCH_FOUND', ?)",
                me, ts(Instant.now().minus(Duration.ofDays(2))));
        jdbc.update("INSERT INTO notifications (recipient_id, type, created_at) VALUES (?, 'MATCH_FOUND', ?)",
                me, ts(Instant.now().minus(Duration.ofDays(89))));
        jdbc.update("INSERT INTO notifications (recipient_id, type, deleted_at) VALUES (?, 'MATCH_FOUND', now())", me);

        // Another instance holds the lock: nothing happens
        boolean[] ranInside = {false};
        jobLock.runWithLock("notification_cleanup", Duration.ofMinutes(1), () -> {
            cleanupJob.run();
            ranInside[0] = true;
        });
        assertThat(ranInside[0]).isTrue();
        assertThat(count("SELECT COUNT(*) FROM notifications WHERE recipient_id = ?", me)).isEqualTo(4);

        cleanupJob.run();
        assertThat(count("SELECT COUNT(*) FROM notifications WHERE recipient_id = ?", me)).isEqualTo(2);
    }
}
