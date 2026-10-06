package com.meeplehearth.notification;

import com.meeplehearth.common.job.JobLock;
import com.meeplehearth.notification.job.NotificationCleanupJob;
import com.meeplehearth.notification.presence.WebSocketPresenceListener;
import com.meeplehearth.notification.repository.NotificationRepository;
import com.meeplehearth.notification.service.NotificationAccountListener;
import com.meeplehearth.notification.service.UnreadCounter;
import com.meeplehearth.common.event.UserHardDeletedEvent;
import com.meeplehearth.support.social.ApiIntegrationTestBase;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ZSetOperations;
import org.springframework.messaging.Message;
import org.springframework.messaging.simp.SimpMessageHeaderAccessor;
import org.springframework.messaging.simp.SimpMessageType;
import org.springframework.messaging.support.MessageBuilder;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.messaging.SessionConnectedEvent;
import org.springframework.web.socket.messaging.SessionDisconnectEvent;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
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
    @Autowired private NotificationAccountListener accountListener;

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
    void presenceIsSharedAcrossInstances() {
        UUID me = UUID.randomUUID();
        String key = WebSocketPresenceListener.key(me);
        keys.add(key);
        UsernamePasswordAuthenticationToken principal = new UsernamePasswordAuthenticationToken(me.toString(), null);
        WebSocketPresenceListener instanceA = new WebSocketPresenceListener(redis);
        WebSocketPresenceListener instanceB = new WebSocketPresenceListener(redis);

        instanceA.onConnected(new SessionConnectedEvent(this, connectedMessage("a-" + me), principal));
        instanceB.onConnected(new SessionConnectedEvent(this, connectedMessage("b-" + me), principal));
        assertThat(redis.opsForZSet().size(key)).isEqualTo(2);

        // The user's only session on A closes: B still holds one, so the user stays online
        instanceA.onDisconnect(new SessionDisconnectEvent(this, connectedMessage("a-" + me), "a-" + me,
                CloseStatus.NORMAL, principal));
        assertThat(instanceA.isOnline(me)).isTrue();
        assertThat(presence.isOnline(me)).isTrue();

        instanceB.onDisconnect(new SessionDisconnectEvent(this, connectedMessage("b-" + me), "b-" + me,
                CloseStatus.NORMAL, principal));
        assertThat(instanceA.isOnline(me)).isFalse();
    }

    @Test
    void aDeadInstancesClaimExpires() {
        UUID me = UUID.randomUUID();
        String key = WebSocketPresenceListener.key(me);
        keys.add(key);
        Instant start = Instant.now();
        WebSocketPresenceListener crashed = new WebSocketPresenceListener(redis, Clock.fixed(start, ZoneOffset.UTC));
        crashed.onConnected(new SessionConnectedEvent(this, connectedMessage("c-" + me),
                new UsernamePasswordAuthenticationToken(me.toString(), null)));

        WebSocketPresenceListener later = new WebSocketPresenceListener(redis,
                Clock.fixed(start.plus(Duration.ofSeconds(31)), ZoneOffset.UTC));
        assertThat(later.isOnline(me)).isFalse();
        WebSocketPresenceListener soon = new WebSocketPresenceListener(redis,
                Clock.fixed(start.plus(Duration.ofSeconds(29)), ZoneOffset.UTC));
        assertThat(soon.isOnline(me)).isTrue();

        // A heartbeat from another instance prunes the dead member
        soon.onConnected(new SessionConnectedEvent(this, connectedMessage("s-" + me),
                new UsernamePasswordAuthenticationToken(me.toString(), null)));
        later.refresh();
        WebSocketPresenceListener muchLater = new WebSocketPresenceListener(redis,
                Clock.fixed(start.plus(Duration.ofSeconds(45)), ZoneOffset.UTC));
        muchLater.onConnected(new SessionConnectedEvent(this, connectedMessage("m-" + me),
                new UsernamePasswordAuthenticationToken(me.toString(), null)));
        assertThat(redis.opsForZSet().score(key, crashed.instanceId())).isNull();
    }

    @Test
    void anOldStringPresenceKeyIsReplaced() {
        UUID me = UUID.randomUUID();
        String key = WebSocketPresenceListener.key(me);
        keys.add(key);
        redis.opsForValue().set(key, "1", Duration.ofSeconds(30));
        assertThat(presence.isOnline(me)).isFalse();
        WebSocketPresenceListener listener = new WebSocketPresenceListener(redis);
        listener.onConnected(new SessionConnectedEvent(this, connectedMessage("o-" + me),
                new UsernamePasswordAuthenticationToken(me.toString(), null)));
        assertThat(listener.isOnline(me)).isTrue();
    }

    @Test
    void presenceTreatsRedisErrorsAsOffline() {
        StringRedisTemplate broken = mock(StringRedisTemplate.class);
        @SuppressWarnings("unchecked")
        ZSetOperations<String, String> ops = mock(ZSetOperations.class);
        when(broken.opsForZSet()).thenReturn(ops);
        when(ops.count(anyString(), any(Double.class), any(Double.class))).thenThrow(new IllegalStateException("down"));
        when(ops.remove(anyString(), any())).thenThrow(new IllegalStateException("down"));
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

    @Test
    void cleanupEvictsTheUnreadCounterOfRecipientsWhoLostUnreadRows() {
        UUID me = user();
        UUID other = user();
        keys.add("notif:unread:" + me);
        keys.add("notif:unread:" + other);
        jdbc.update("INSERT INTO notifications (recipient_id, type, created_at) VALUES (?, 'MATCH_FOUND', ?)",
                me, ts(Instant.now().minus(Duration.ofDays(91))));
        jdbc.update("INSERT INTO notifications (recipient_id, type) VALUES (?, 'MATCH_FOUND')", me);
        jdbc.update("INSERT INTO notifications (recipient_id, type, read, created_at) VALUES (?, 'MATCH_FOUND', true, ?)",
                other, ts(Instant.now().minus(Duration.ofDays(91))));
        jdbc.update("INSERT INTO notifications (recipient_id, type) VALUES (?, 'MATCH_FOUND')", other);
        assertThat(counter.get(me)).isEqualTo(2);
        assertThat(counter.get(other)).isEqualTo(1);

        cleanupJob.run();

        assertThat(redis.hasKey("notif:unread:" + me)).isFalse();
        assertThat(counter.get(me)).isEqualTo(1);
        // A read row does not change the badge: that counter is left alone
        assertThat(redis.opsForValue().get("notif:unread:" + other)).isEqualTo("1");
    }

    @Test
    void hardDeletingAnActorEvictsTheCountersOfTheirRecipients() {
        UUID actor = user();
        UUID recipient = user();
        keys.add("notif:unread:" + recipient);
        jdbc.update("INSERT INTO notifications (recipient_id, actor_id, type) VALUES (?, ?, 'POST_TAG')", recipient, actor);
        jdbc.update("INSERT INTO notifications (recipient_id, type) VALUES (?, 'MATCH_FOUND')", recipient);
        assertThat(counter.get(recipient)).isEqualTo(2);

        accountListener.onHardDeleted(new UserHardDeletedEvent(actor));

        assertThat(redis.hasKey("notif:unread:" + recipient)).isFalse();
        assertThat(counter.get(recipient)).isEqualTo(1);
    }
}
