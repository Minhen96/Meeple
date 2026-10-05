package com.meeplehearth.config;

import com.meeplehearth.auth.service.UserDetailsServiceImpl;
import com.meeplehearth.auth.util.JwtUtil;
import com.meeplehearth.common.exception.ApiException;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import org.junit.jupiter.api.Test;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.MessageDeliveryException;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.MessageBuilder;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.WebSocketSession;

import java.security.Principal;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class WebSocketAndOriginSecurityTest {

    private final JwtUtil jwtUtil = mock(JwtUtil.class);
    private final UserDetailsServiceImpl userDetailsService = mock(UserDetailsServiceImpl.class);
    private static final Instant NOW = Instant.parse("2026-10-05T12:00:00Z");
    private final WebSocketSessionRevoker revoker = new WebSocketSessionRevoker(Clock.fixed(NOW, ZoneOffset.UTC));
    private final WebSocketConfig.StompAuthorizationInterceptor interceptor =
            new WebSocketConfig.StompAuthorizationInterceptor(jwtUtil, userDetailsService, revoker);
    private final MessageChannel channel = mock(MessageChannel.class);

    private static Message<byte[]> frame(StompCommand command, String destination, String bearer, Principal user) {
        Map<String, Object> attributes = new HashMap<>();
        attributes.put(WebSocketSessionRevoker.TOKEN_EXPIRES_AT_ATTR, NOW.plusSeconds(600).toEpochMilli());
        return frame(command, destination, bearer, user, "session-1", attributes);
    }

    private static Message<byte[]> frame(StompCommand command, String destination, String bearer, Principal user,
                                         String sessionId, Map<String, Object> sessionAttributes) {
        StompHeaderAccessor accessor = StompHeaderAccessor.create(command);
        accessor.setSessionId(sessionId);
        accessor.setSessionAttributes(sessionAttributes);
        if (destination != null) {
            accessor.setDestination(destination);
        }
        if (bearer != null) {
            accessor.setNativeHeader("Authorization", "Bearer " + bearer);
        }
        if (user != null) {
            accessor.setUser(user);
        }
        accessor.setLeaveMutable(true);
        return MessageBuilder.createMessage(new byte[0], accessor.getMessageHeaders());
    }

    private static Principal user(UUID id) {
        return new UsernamePasswordAuthenticationToken(id.toString(), null, List.of());
    }

    @Test
    void connectWithoutTokenIsRejected() {
        assertThatThrownBy(() -> interceptor.preSend(frame(StompCommand.CONNECT, null, null, null), channel))
                .isInstanceOf(MessageDeliveryException.class);
    }

    @Test
    void connectWithInvalidTokenIsRejected() {
        when(jwtUtil.validateAccessToken("bad")).thenThrow(ApiException.unauthorized("Invalid"));

        assertThatThrownBy(() -> interceptor.preSend(frame(StompCommand.CONNECT, null, "bad", null), channel))
                .isInstanceOf(MessageDeliveryException.class);
    }

    @Test
    void connectWithRevokedTokenIsRejected() {
        UUID id = UUID.randomUUID();
        Claims claims = Jwts.claims().subject(id.toString()).add(JwtUtil.TOKEN_VERSION_CLAIM, 0).build();
        when(jwtUtil.validateAccessToken("stale")).thenReturn(claims);
        when(userDetailsService.loadUserForAccessToken(org.mockito.ArgumentMatchers.eq(id), anyInt()))
                .thenThrow(new UsernameNotFoundException("revoked"));

        assertThatThrownBy(() -> interceptor.preSend(frame(StompCommand.CONNECT, null, "stale", null), channel))
                .isInstanceOf(MessageDeliveryException.class);
    }

    @Test
    void connectWithValidTokenSetsPrincipalNameToUserId() {
        UUID id = UUID.randomUUID();
        Claims claims = Jwts.claims().subject(id.toString()).add(JwtUtil.TOKEN_VERSION_CLAIM, 2).build();
        when(jwtUtil.validateAccessToken("good")).thenReturn(claims);
        when(userDetailsService.loadUserForAccessToken(id, 2)).thenReturn(
                User.withUsername(id.toString()).password("").authorities("ROLE_USER").build());

        Message<?> out = interceptor.preSend(frame(StompCommand.CONNECT, null, "good", null), channel);

        Principal principal = StompHeaderAccessor.wrap(out).getUser();
        assertThat(principal).isNotNull();
        assertThat(principal.getName()).isEqualTo(id.toString());
    }

    @Test
    void subscriptionRules() {
        UUID me = UUID.randomUUID();
        Principal principal = user(me);

        interceptor.preSend(frame(StompCommand.SUBSCRIBE, "/user/queue/notifications", null, principal), channel);
        interceptor.preSend(frame(StompCommand.SUBSCRIBE, "/topic/how-to-play/" + UUID.randomUUID(), null, principal),
                channel);

        for (String forbidden : List.of(
                "/topic/notifications/" + me,
                "/topic/notifications/" + UUID.randomUUID(),
                "/user/" + UUID.randomUUID() + "/queue/notifications",
                "/queue/notifications-userabc123",
                "/topic/anything-else")) {
            assertThatThrownBy(() -> interceptor.preSend(frame(StompCommand.SUBSCRIBE, forbidden, null, principal), channel))
                    .as(forbidden)
                    .isInstanceOf(MessageDeliveryException.class);
        }

        assertThatThrownBy(() -> interceptor.preSend(
                frame(StompCommand.SUBSCRIBE, "/user/queue/notifications", null, null), channel))
                .isInstanceOf(MessageDeliveryException.class);
    }

    @Test
    void clientsCannotPublishToBrokerDestinations() {
        Principal principal = user(UUID.randomUUID());

        assertThatThrownBy(() -> interceptor.preSend(
                frame(StompCommand.SEND, "/topic/how-to-play/" + UUID.randomUUID(), null, principal), channel))
                .isInstanceOf(MessageDeliveryException.class);
        interceptor.preSend(frame(StompCommand.SEND, "/app/ping", null, principal), channel);
    }

    @Test
    void connectRecordsTokenExpiryAndAuthenticationTime() {
        UUID id = UUID.randomUUID();
        Instant exp = NOW.plusSeconds(900);
        Claims claims = Jwts.claims().subject(id.toString()).add(JwtUtil.TOKEN_VERSION_CLAIM, 0)
                .expiration(Date.from(exp)).build();
        when(jwtUtil.validateAccessToken("good")).thenReturn(claims);
        when(userDetailsService.loadUserForAccessToken(id, 0)).thenReturn(
                User.withUsername(id.toString()).password("").authorities("ROLE_USER").build());
        Map<String, Object> attributes = new HashMap<>();

        interceptor.preSend(frame(StompCommand.CONNECT, null, "good", null, "s", attributes), channel);

        assertThat(attributes.get(WebSocketSessionRevoker.TOKEN_EXPIRES_AT_ATTR)).isEqualTo(exp.toEpochMilli());
        assertThat(attributes.get(WebSocketSessionRevoker.AUTHENTICATED_AT_ATTR)).isEqualTo(NOW.toEpochMilli());
    }

    @Test
    void subscribeOrSendAfterTokenExpiryIsRejectedAndSocketClosed() throws Exception {
        Principal principal = user(UUID.randomUUID());
        WebSocketSession session = mock(WebSocketSession.class);
        when(session.getId()).thenReturn("expired-session");
        when(session.isOpen()).thenReturn(true);
        revoker.decorate(mock(WebSocketHandler.class)).afterConnectionEstablished(session);

        Map<String, Object> expired = new HashMap<>();
        expired.put(WebSocketSessionRevoker.TOKEN_EXPIRES_AT_ATTR, NOW.toEpochMilli());

        assertThatThrownBy(() -> interceptor.preSend(frame(StompCommand.SUBSCRIBE, "/user/queue/notifications",
                null, principal, "expired-session", expired), channel))
                .isInstanceOf(MessageDeliveryException.class);
        assertThatThrownBy(() -> interceptor.preSend(frame(StompCommand.SEND, "/app/ping",
                null, principal, "expired-session", expired), channel))
                .isInstanceOf(MessageDeliveryException.class);
        // No recorded expiry counts as expired
        assertThatThrownBy(() -> interceptor.preSend(frame(StompCommand.SUBSCRIBE, "/user/queue/notifications",
                null, principal, "expired-session", new HashMap<>()), channel))
                .isInstanceOf(MessageDeliveryException.class);

        verify(session, org.mockito.Mockito.atLeastOnce()).close(WebSocketSessionRevoker.TOKEN_EXPIRED);
    }

    @Test
    void originCheck() {
        OriginCheckFilter filter = new OriginCheckFilter(List.of("https://meeple.example.com"));

        assertThat(filter.isAllowed("https://meeple.example.com", null)).isTrue();
        assertThat(filter.isAllowed("https://MEEPLE.example.com/", null)).isTrue();
        assertThat(filter.isAllowed("https://evil.example.com", null)).isFalse();
        assertThat(filter.isAllowed("null", null)).isFalse();
        assertThat(filter.isAllowed(null, "https://meeple.example.com/events/1")).isTrue();
        assertThat(filter.isAllowed(null, "https://evil.example.com/page")).isFalse();
        assertThat(filter.isAllowed(null, null)).isTrue();
    }
}
