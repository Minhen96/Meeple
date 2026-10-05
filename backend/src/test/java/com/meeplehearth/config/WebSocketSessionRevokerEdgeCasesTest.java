package com.meeplehearth.config;

import org.junit.jupiter.api.Test;
import org.springframework.messaging.simp.SimpMessageHeaderAccessor;
import org.springframework.messaging.support.MessageBuilder;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.messaging.SessionConnectedEvent;

import java.io.IOException;
import java.security.Principal;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Defensive branches of the session registry: missing ids, stale state and failing closes. */
class WebSocketSessionRevokerEdgeCasesTest {

    private final AtomicReference<Instant> now = new AtomicReference<>(Instant.parse("2026-10-05T12:00:00Z"));
    private final WebSocketSessionRevoker revoker = new WebSocketSessionRevoker(new Clock() {
        @Override public ZoneId getZone() { return ZoneOffset.UTC; }
        @Override public Clock withZone(ZoneId zone) { return this; }
        @Override public Instant instant() { return now.get(); }
    });
    private final WebSocketHandler handler = revoker.decorate(mock(WebSocketHandler.class));

    private WebSocketSession open(String id, Map<String, Object> attributes) throws Exception {
        WebSocketSession session = mock(WebSocketSession.class);
        when(session.getId()).thenReturn(id);
        when(session.isOpen()).thenReturn(true);
        when(session.getAttributes()).thenReturn(attributes);
        handler.afterConnectionEstablished(session);
        return session;
    }

    private static SessionConnectedEvent connectedEvent(String sessionId, Principal user) {
        SimpMessageHeaderAccessor accessor = SimpMessageHeaderAccessor.create();
        if (sessionId != null) {
            accessor.setSessionId(sessionId);
        }
        return new SessionConnectedEvent(new Object(),
                MessageBuilder.createMessage(new byte[0], accessor.getMessageHeaders()), user);
    }

    private static Principal principal(UUID userId) {
        return new UsernamePasswordAuthenticationToken(userId.toString(), null, List.of());
    }

    @Test
    void connectedEventsWithoutSessionIdOrUserAreIgnored() throws Exception {
        UUID userId = UUID.randomUUID();
        open("s1", new HashMap<>());

        revoker.onSessionConnected(connectedEvent(null, principal(userId)));
        revoker.onSessionConnected(connectedEvent("s1", null));

        assertThat(revoker.sessionCount(userId)).isZero();
    }

    @Test
    void sessionAuthenticatedAfterTheRevocationSurvivesRegistration() throws Exception {
        UUID userId = UUID.randomUUID();
        revoker.revokeUser(userId);
        now.set(now.get().plusSeconds(1));
        Map<String, Object> attributes = new HashMap<>();
        attributes.put(WebSocketSessionRevoker.AUTHENTICATED_AT_ATTR, now.get().toEpochMilli());
        WebSocketSession fresh = open("fresh", attributes);

        revoker.onSessionConnected(connectedEvent("fresh", principal(userId)));

        verify(fresh, never()).close(any(CloseStatus.class));
        assertThat(revoker.sessionCount(userId)).isEqualTo(1);
    }

    @Test
    void revokedUserBindingAnUntrackedSessionIsANoOp() {
        UUID userId = UUID.randomUUID();
        revoker.revokeUser(userId);

        assertThatCode(() -> revoker.bind("never-opened", userId.toString())).doesNotThrowAnyException();
        assertThat(revoker.sessionCount(userId)).isEqualTo(1);
    }

    @Test
    void revocationsAreForgottenAfterTheMemoryWindow() throws Exception {
        UUID oldUser = UUID.randomUUID();
        revoker.revokeUser(oldUser);
        now.set(now.get().plus(WebSocketSessionRevoker.REVOCATION_MEMORY).plus(Duration.ofSeconds(1)));
        // Any later revocation prunes expired entries
        revoker.revokeUser(UUID.randomUUID());

        // A session without an authentication time registering now is no longer closed for oldUser
        WebSocketSession late = open("late", new HashMap<>());
        revoker.bind("late", oldUser.toString());

        verify(late, never()).close(any(CloseStatus.class));
    }

    @Test
    void unregisterToleratesUnknownAndNullIdsAndKeepsOtherSessions() throws Exception {
        UUID userId = UUID.randomUUID();
        open("a", new HashMap<>());
        WebSocketSession b = open("b", new HashMap<>());
        revoker.bind("a", userId.toString());
        revoker.bind("b", userId.toString());

        revoker.unregister(null);
        revoker.unregister("unknown");
        revoker.unregister("a");

        assertThat(revoker.sessionCount(userId)).isEqualTo(1);
        revoker.revokeUser(userId);
        verify(b).close(WebSocketSessionRevoker.REVOKED);
    }

    @Test
    void revokingNullOrSessionlessUsersDoesNothing() {
        assertThatCode(() -> revoker.revokeUser(null)).doesNotThrowAnyException();
        assertThatCode(() -> revoker.revokeUser(UUID.randomUUID())).doesNotThrowAnyException();
        assertThatCode(() -> revoker.closeSession(null, CloseStatus.NORMAL)).doesNotThrowAnyException();
        assertThatCode(() -> revoker.closeSession("unknown", CloseStatus.NORMAL)).doesNotThrowAnyException();
    }

    @Test
    void failuresWhileClosingAreSwallowed() throws Exception {
        UUID userId = UUID.randomUUID();
        WebSocketSession broken = open("broken", new HashMap<>());
        doThrow(new IOException("socket already gone")).when(broken).close(any(CloseStatus.class));
        WebSocketSession alreadyClosed = open("closed", new HashMap<>());
        when(alreadyClosed.isOpen()).thenReturn(false);
        revoker.bind("broken", userId.toString());
        revoker.bind("closed", userId.toString());

        assertThatCode(() -> revoker.revokeUser(userId)).doesNotThrowAnyException();

        verify(broken).close(WebSocketSessionRevoker.REVOKED);
        verify(alreadyClosed, never()).close(any(CloseStatus.class));
    }

    @Test
    void expirySweepIgnoresSessionsWithoutARecordedExpiry() throws Exception {
        WebSocketSession unauthenticated = open("pending", new HashMap<>());
        Map<String, Object> notYet = new HashMap<>();
        notYet.put(WebSocketSessionRevoker.TOKEN_EXPIRES_AT_ATTR, now.get().plusSeconds(60).toEpochMilli());
        WebSocketSession valid = open("valid", notYet);

        revoker.closeExpiredSessions();

        verify(unauthenticated, never()).close(any(CloseStatus.class));
        verify(valid, never()).close(any(CloseStatus.class));
    }
}
