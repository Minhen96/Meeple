package com.meeplehearth.config;

import com.meeplehearth.auth.event.UserSessionsRevokedEvent;
import org.junit.jupiter.api.Test;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.SimpMessageHeaderAccessor;
import org.springframework.messaging.support.MessageBuilder;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.annotation.EnableTransactionManagement;
import org.springframework.transaction.support.AbstractPlatformTransactionManager;
import org.springframework.transaction.support.DefaultTransactionStatus;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.messaging.SessionConnectedEvent;
import org.springframework.web.socket.messaging.SessionDisconnectEvent;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class WebSocketSessionRevokerTest {

    private final AtomicReference<Instant> now = new AtomicReference<>(Instant.parse("2026-10-05T12:00:00Z"));
    private final Clock clock = new Clock() {
        @Override public ZoneId getZone() { return ZoneOffset.UTC; }
        @Override public Clock withZone(ZoneId zone) { return this; }
        @Override public Instant instant() { return now.get(); }
    };
    private final WebSocketSessionRevoker revoker = new WebSocketSessionRevoker(clock);
    private final WebSocketHandler handler = revoker.decorate(mock(WebSocketHandler.class));

    private WebSocketSession open(String id, Long authenticatedAt) throws Exception {
        WebSocketSession session = mock(WebSocketSession.class);
        Map<String, Object> attributes = new HashMap<>();
        if (authenticatedAt != null) {
            attributes.put(WebSocketSessionRevoker.AUTHENTICATED_AT_ATTR, authenticatedAt);
        }
        when(session.getId()).thenReturn(id);
        when(session.isOpen()).thenReturn(true);
        when(session.getAttributes()).thenReturn(attributes);
        handler.afterConnectionEstablished(session);
        return session;
    }

    private void connected(String sessionId, UUID userId) {
        SimpMessageHeaderAccessor accessor = SimpMessageHeaderAccessor.create();
        accessor.setSessionId(sessionId);
        revoker.onSessionConnected(new SessionConnectedEvent(this,
                MessageBuilder.createMessage(new byte[0], accessor.getMessageHeaders()),
                new UsernamePasswordAuthenticationToken(userId.toString(), null, List.of())));
    }

    @Test
    void revokeUserClosesOnlyThatUsersSessions() throws Exception {
        UUID alice = UUID.randomUUID();
        UUID bob = UUID.randomUUID();
        long t = now.get().toEpochMilli();
        WebSocketSession a1 = open("a1", t);
        WebSocketSession a2 = open("a2", t);
        WebSocketSession b1 = open("b1", t);
        connected("a1", alice);
        connected("a2", alice);
        connected("b1", bob);

        now.set(now.get().plusSeconds(1));
        revoker.revokeUser(alice);

        verify(a1).close(CloseStatus.POLICY_VIOLATION.withReason("Session revoked"));
        verify(a2).close(WebSocketSessionRevoker.REVOKED);
        verify(b1, never()).close(any());
        assertThat(revoker.sessionCount(bob)).isEqualTo(1);
    }

    @Test
    void disconnectedSessionsAreForgotten() throws Exception {
        UUID alice = UUID.randomUUID();
        WebSocketSession a1 = open("a1", now.get().toEpochMilli());
        connected("a1", alice);
        assertThat(revoker.sessionCount(alice)).isEqualTo(1);

        revoker.onSessionDisconnect(new SessionDisconnectEvent(this,
                MessageBuilder.withPayload(new byte[0]).build(), "a1", CloseStatus.NORMAL));
        handler.afterConnectionClosed(a1, CloseStatus.NORMAL);

        assertThat(revoker.sessionCount(alice)).isZero();
        revoker.revokeUser(alice);
        verify(a1, never()).close(any());
    }

    @Test
    void sessionAuthenticatedBeforeRevocationButRegisteredAfterIsClosed() throws Exception {
        UUID alice = UUID.randomUUID();
        long authenticatedBefore = now.get().toEpochMilli();
        now.set(now.get().plusMillis(50));
        revoker.revokeUser(alice);

        WebSocketSession stale = open("stale", authenticatedBefore);
        connected("stale", alice);
        verify(stale).close(WebSocketSessionRevoker.REVOKED);

        now.set(now.get().plusMillis(50));
        WebSocketSession fresh = open("fresh", now.get().toEpochMilli());
        connected("fresh", alice);
        verify(fresh, never()).close(any());
    }

    @Test
    void revocationEventIsAppliedOnlyAfterCommit() throws Exception {
        UUID alice = UUID.randomUUID();
        WebSocketSession a1 = open("a1", now.get().toEpochMilli());
        connected("a1", alice);
        now.set(now.get().plusSeconds(1));

        try (AnnotationConfigApplicationContext ctx = new AnnotationConfigApplicationContext()) {
            ctx.registerBean(WebSocketSessionRevoker.class, () -> revoker);
            ctx.register(TxConfig.class);
            ctx.refresh();
            TransactionTemplate tx = new TransactionTemplate(ctx.getBean(PlatformTransactionManager.class));

            tx.executeWithoutResult(status -> {
                ctx.publishEvent(new UserSessionsRevokedEvent(alice));
                status.setRollbackOnly();
            });
            verify(a1, never()).close(any());

            tx.executeWithoutResult(status -> {
                ctx.publishEvent(new UserSessionsRevokedEvent(alice));
                assertThat(org.mockito.Mockito.mockingDetails(a1).getInvocations())
                        .noneMatch(invocation -> invocation.getMethod().getName().equals("close"));
            });
            verify(a1).close(WebSocketSessionRevoker.REVOKED);
        }
    }

    @Configuration
    @EnableTransactionManagement
    static class TxConfig {
        @Bean
        PlatformTransactionManager transactionManager() {
            return new AbstractPlatformTransactionManager() {
                @Override protected Object doGetTransaction() { return new Object(); }
                @Override protected void doBegin(Object transaction, TransactionDefinition definition) { }
                @Override protected void doCommit(DefaultTransactionStatus status) { }
                @Override protected void doRollback(DefaultTransactionStatus status) { }
            };
        }
    }
}
