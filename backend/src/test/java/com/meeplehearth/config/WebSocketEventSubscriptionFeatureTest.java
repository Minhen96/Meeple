package com.meeplehearth.config;

import com.meeplehearth.auth.service.UserDetailsServiceImpl;
import com.meeplehearth.auth.util.JwtUtil;
import org.junit.jupiter.api.Test;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.MessageDeliveryException;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.MessageBuilder;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;

import java.security.Principal;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;

/** SUBSCRIBE to /topic/events/{eventId} is allowed only for viewers who can see the event. */
class WebSocketEventSubscriptionFeatureTest {

    private static final Instant NOW = Instant.parse("2026-10-05T12:00:00Z");
    private final WebSocketSessionRevoker revoker = new WebSocketSessionRevoker(Clock.fixed(NOW, ZoneOffset.UTC));
    private final UUID viewer = UUID.randomUUID();
    private final UUID visibleEvent = UUID.randomUUID();
    private final AtomicReference<UUID[]> lastCheck = new AtomicReference<>();
    private final WebSocketConfig.StompAuthorizationInterceptor interceptor =
            new WebSocketConfig.StompAuthorizationInterceptor(mock(JwtUtil.class), mock(UserDetailsServiceImpl.class),
                    revoker, (eventId, userId) -> {
                        lastCheck.set(new UUID[]{eventId, userId});
                        if (eventId.getMostSignificantBits() == 42L) {
                            throw new IllegalStateException("db down");
                        }
                        return eventId.equals(visibleEvent) && userId.equals(viewer);
                    });

    private Message<byte[]> subscribe(String destination, Principal user) {
        StompHeaderAccessor accessor = StompHeaderAccessor.create(StompCommand.SUBSCRIBE);
        accessor.setSessionId("s-1");
        Map<String, Object> attributes = new HashMap<>();
        attributes.put(WebSocketSessionRevoker.TOKEN_EXPIRES_AT_ATTR, NOW.plusSeconds(600).toEpochMilli());
        accessor.setSessionAttributes(attributes);
        accessor.setDestination(destination);
        accessor.setUser(user);
        accessor.setLeaveMutable(true);
        return MessageBuilder.createMessage(new byte[0], accessor.getMessageHeaders());
    }

    private Principal principal(UUID id) {
        return new UsernamePasswordAuthenticationToken(id.toString(), null, java.util.List.of());
    }

    @Test
    void allowsVisibleEventsOnly() {
        MessageChannel channel = mock(MessageChannel.class);
        Message<byte[]> ok = subscribe("/topic/events/" + visibleEvent, principal(viewer));
        assertThat(interceptor.preSend(ok, channel)).isSameAs(ok);
        assertThat(lastCheck.get()).containsExactly(visibleEvent, viewer);

        assertThatThrownBy(() -> interceptor.preSend(
                subscribe("/topic/events/" + UUID.randomUUID(), principal(viewer)), channel))
                .isInstanceOf(MessageDeliveryException.class);
        assertThatThrownBy(() -> interceptor.preSend(
                subscribe("/topic/events/" + visibleEvent, principal(UUID.randomUUID())), channel))
                .isInstanceOf(MessageDeliveryException.class);
    }

    @Test
    void rejectsMalformedDestinationsAndFailures() {
        Principal user = principal(viewer);
        assertThat(interceptor.isEventSubscriptionAllowed("/topic/events/not-a-uuid", user)).isFalse();
        assertThat(interceptor.isEventSubscriptionAllowed("/topic/events/1-1-1-1-1", user)).isFalse();
        assertThat(interceptor.isEventSubscriptionAllowed("/topic/events/" + visibleEvent + "/x", user)).isFalse();
        assertThat(interceptor.isEventSubscriptionAllowed("/topic/events/" + new UUID(42L, 1L), user)).isFalse();
        assertThat(interceptor.isEventSubscriptionAllowed("/topic/other/" + visibleEvent, user)).isFalse();
        assertThat(interceptor.isEventSubscriptionAllowed(null, user)).isFalse();
        assertThat(interceptor.isEventSubscriptionAllowed("/topic/events/" + visibleEvent, null)).isFalse();
        assertThat(interceptor.isEventSubscriptionAllowed("/topic/events/" + visibleEvent,
                () -> "not-a-uuid")).isFalse();
        assertThat(interceptor.isEventSubscriptionAllowed("/topic/events/" + visibleEvent.toString().toUpperCase(),
                user)).isTrue();
    }

    @Test
    void interceptorWithoutVisibilityCheckRefusesEventTopics() {
        WebSocketConfig.StompAuthorizationInterceptor legacy = new WebSocketConfig.StompAuthorizationInterceptor(
                mock(JwtUtil.class), mock(UserDetailsServiceImpl.class), revoker);
        assertThat(legacy.isEventSubscriptionAllowed("/topic/events/" + visibleEvent, principal(viewer))).isFalse();
    }
}
