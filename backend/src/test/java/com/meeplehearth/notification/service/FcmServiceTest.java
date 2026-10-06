package com.meeplehearth.notification.service;

import com.google.firebase.messaging.BatchResponse;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.SendResponse;
import com.meeplehearth.notification.entity.UserFcmToken;
import com.meeplehearth.notification.repository.NotificationRepository;
import com.meeplehearth.notification.repository.UserFcmTokenRepository;
import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;
import org.junit.jupiter.api.BeforeEach;
import com.google.firebase.IncomingHttpResponse;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.MessagingErrorCode;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.SimpleTransactionStatus;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class FcmServiceTest {

    private final FirebaseMessaging messaging = mock(FirebaseMessaging.class);
    @SuppressWarnings("unchecked")
    private final ObjectProvider<FirebaseMessaging> provider = mock(ObjectProvider.class);
    private final UserFcmTokenRepository tokens = mock(UserFcmTokenRepository.class);
    private final NotificationRepository notifications = mock(NotificationRepository.class);
    private final PlatformTransactionManager txManager = mock(PlatformTransactionManager.class);
    private CircuitBreakerRegistry registry;
    private FcmService service;
    private final UUID userId = UUID.randomUUID();

    private final FcmService.PushMessage message = new FcmService.PushMessage(UUID.randomUUID(), userId,
            "POST_LIKE", "New Like", "Ana liked your post", Map.of("path", "/posts/1", "count", 1), 2);

    @BeforeEach
    void setUp() {
        when(provider.getIfAvailable()).thenReturn(messaging);
        when(txManager.getTransaction(any())).thenReturn(new SimpleTransactionStatus());
        registry = CircuitBreakerRegistry.ofDefaults();
        service = new FcmService(provider, tokens, notifications, registry, txManager);
    }

    private void devices(int n) {
        List<UserFcmToken> rows = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            UserFcmToken t = new UserFcmToken();
            t.setToken("t" + i);
            rows.add(t);
        }
        when(tokens.findByUserIdOrderByUpdatedAtDesc(userId)).thenReturn(rows);
    }

    @Test
    void disabledIsANoOp() {
        when(provider.getIfAvailable()).thenReturn(null);
        assertThat(service.isEnabled()).isFalse();
        assertThat(service.send(message)).isZero();
        verifyNoInteractions(tokens, messaging);
    }

    @Test
    void noDevicesSendsNothing() {
        devices(0);
        assertThat(service.send(message)).isZero();
        verifyNoInteractions(messaging);
    }

    @Test
    void chunksAtFiveHundredAndMarksPushed() throws Exception {
        devices(501);
        when(messaging.sendEach(anyList())).thenAnswer(inv -> {
            List<?> batch = inv.getArgument(0);
            BatchResponse r = mock(BatchResponse.class);
            List<SendResponse> list = new ArrayList<>();
            for (int i = 0; i < batch.size(); i++) {
                SendResponse ok = mock(SendResponse.class);
                when(ok.isSuccessful()).thenReturn(true);
                list.add(ok);
            }
            when(r.getResponses()).thenReturn(list);
            return r;
        });

        assertThat(service.send(message)).isEqualTo(501);
        verify(messaging, times(2)).sendEach(anyList());
        verify(notifications).markPushed(message.notificationId());
        verify(tokens, never()).deleteByTokenIn(any());
    }

    @Test
    void wholeCallFailureIsSwallowedAndOpensTheBreakerEventually() throws Exception {
        devices(1);
        when(messaging.sendEach(anyList())).thenThrow(new IllegalStateException(new IOException("network")));
        for (int i = 0; i < 120; i++) {
            assertThat(service.send(message)).isZero();
        }
        assertThat(registry.circuitBreaker("fcm").getState().name()).isEqualTo("OPEN");
        verify(notifications, never()).markPushed(any());
    }

    @Test
    void buildCarriesTextDataAndBadge() {
        List<Message> built = FcmService.build(message, List.of("a", "b"));
        assertThat(built).hasSize(2);
    }

    @Test
    void sendAsyncDelegates() {
        when(provider.getIfAvailable()).thenReturn(null);
        service.sendAsync(message);
        verifyNoInteractions(tokens);
    }

    private static FirebaseMessagingException fcmError(MessagingErrorCode code, String message, String body) {
        FirebaseMessagingException e = mock(FirebaseMessagingException.class);
        when(e.getMessagingErrorCode()).thenReturn(code);
        when(e.getMessage()).thenReturn(message);
        if (body != null) {
            IncomingHttpResponse response = mock(IncomingHttpResponse.class);
            when(response.getContent()).thenReturn(body);
            when(e.getHttpResponse()).thenReturn(response);
        }
        return e;
    }

    @Test
    void onlyTokenErrorsMarkATokenStale() {
        assertThat(FcmService.isStale(fcmError(MessagingErrorCode.UNREGISTERED, "Requested entity was not found.", null)))
                .isTrue();
        assertThat(FcmService.isStale(fcmError(MessagingErrorCode.SENDER_ID_MISMATCH, null, null))).isTrue();
        assertThat(FcmService.isStale(fcmError(MessagingErrorCode.INVALID_ARGUMENT,
                "The registration token is not a valid FCM registration token", null))).isTrue();
        assertThat(FcmService.isStale(fcmError(MessagingErrorCode.INVALID_ARGUMENT, "Request contains an invalid argument.",
                "{\"error\":{\"details\":[{\"fieldViolations\":[{\"field\":\"message.token\"}]}]}}"))).isTrue();

        // A malformed message is not the token's fault
        assertThat(FcmService.isStale(fcmError(MessagingErrorCode.INVALID_ARGUMENT, "Request contains an invalid argument.",
                "{\"error\":{\"details\":[{\"fieldViolations\":[{\"field\":\"message.data\"}]}]}}"))).isFalse();
        assertThat(FcmService.isStale(fcmError(MessagingErrorCode.INVALID_ARGUMENT, null, null))).isFalse();
        assertThat(FcmService.isStale(fcmError(MessagingErrorCode.UNAVAILABLE, "registration token", null))).isFalse();
        assertThat(FcmService.isStale(fcmError(MessagingErrorCode.QUOTA_EXCEEDED, null, null))).isFalse();
        assertThat(FcmService.isStale(fcmError(null, null, null))).isFalse();
        assertThat(FcmService.isStale(null)).isFalse();
    }
}
