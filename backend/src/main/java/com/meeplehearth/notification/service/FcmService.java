package com.meeplehearth.notification.service;

import com.google.firebase.IncomingHttpResponse;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.ApnsConfig;
import com.google.firebase.messaging.Aps;
import com.google.firebase.messaging.BatchResponse;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.MessagingErrorCode;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.SendResponse;
import com.google.firebase.messaging.WebpushConfig;
import com.meeplehearth.notification.config.NotificationAsyncConfig;
import com.meeplehearth.notification.entity.UserFcmToken;
import com.meeplehearth.notification.repository.NotificationRepository;
import com.meeplehearth.notification.repository.UserFcmTokenRepository;
import io.github.resilience4j.circuitbreaker.CallNotPermittedException;
import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.util.ArrayList;
import java.util.EnumSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * Firebase Cloud Messaging push (FEATURES_COMPLETE section 7.3, TECH_STACK section 7). Called by
 * {@link NotificationService} after the notification committed, only when the recipient is
 * offline, allows push for the type and is outside quiet hours.
 *
 * <ul>
 *   <li>Runs on {@code notificationExecutor} so the request thread never waits on FCM.</li>
 *   <li>Every FCM call goes through the Resilience4j {@code fcm} circuit breaker.</li>
 *   <li>Sends to every registered device of the recipient; tokens FCM reports as
 *       {@code UNREGISTERED} or {@code SENDER_ID_MISMATCH} are deleted, and so are tokens rejected
 *       with an {@code INVALID_ARGUMENT} that is about the token itself (see {@link #isStale}).
 *       Any other error keeps the token.</li>
 *   <li>Sets {@code notifications.is_pushed} once at least one device accepted the message.</li>
 *   <li>A no-op (logged at debug) when {@code FIREBASE_SERVICE_ACCOUNT_JSON} is not set.</li>
 * </ul>
 * Tokens are never logged.
 */
@Service
public class FcmService {

    private static final Logger log = LoggerFactory.getLogger(FcmService.class);

    static final String BREAKER = "fcm";
    /** FCM accepts at most 500 messages per sendEach call. */
    static final int MAX_TOKENS_PER_CALL = 500;

    /** Errors that always mean the token is dead or belongs to another sender. */
    private static final Set<MessagingErrorCode> STALE_TOKEN_ERRORS = EnumSet.of(
            MessagingErrorCode.UNREGISTERED, MessagingErrorCode.SENDER_ID_MISMATCH);

    /** What a push shows and where tapping it leads; a snapshot of the committed notification. */
    public record PushMessage(UUID notificationId, UUID recipientId, String type, String title, String body,
                              Map<String, Object> data, long unreadCount) {
    }

    private final ObjectProvider<FirebaseMessaging> firebaseMessaging;
    private final UserFcmTokenRepository tokenRepository;
    private final NotificationRepository notificationRepository;
    private final CircuitBreaker circuitBreaker;
    private final TransactionTemplate transactionTemplate;

    public FcmService(ObjectProvider<FirebaseMessaging> firebaseMessaging,
                      UserFcmTokenRepository tokenRepository,
                      NotificationRepository notificationRepository,
                      CircuitBreakerRegistry circuitBreakerRegistry,
                      PlatformTransactionManager transactionManager) {
        this.firebaseMessaging = firebaseMessaging;
        this.tokenRepository = tokenRepository;
        this.notificationRepository = notificationRepository;
        this.circuitBreaker = circuitBreakerRegistry.circuitBreaker(BREAKER);
        this.transactionTemplate = new TransactionTemplate(transactionManager);
    }

    public boolean isEnabled() {
        return firebaseMessaging.getIfAvailable() != null;
    }

    @Async(NotificationAsyncConfig.EXECUTOR)
    public void sendAsync(PushMessage message) {
        send(message);
    }

    /**
     * Sends synchronously; never throws.
     *
     * @return number of devices that accepted the push
     */
    public int send(PushMessage message) {
        FirebaseMessaging messaging = firebaseMessaging.getIfAvailable();
        if (messaging == null) {
            log.debug("FCM disabled; push for notification {} skipped", message.notificationId());
            return 0;
        }
        try {
            List<String> tokens = tokenRepository.findByUserIdOrderByUpdatedAtDesc(message.recipientId()).stream()
                    .map(UserFcmToken::getToken)
                    .toList();
            if (tokens.isEmpty()) {
                return 0;
            }

            int delivered = 0;
            List<String> stale = new ArrayList<>();
            for (int from = 0; from < tokens.size(); from += MAX_TOKENS_PER_CALL) {
                List<String> chunk = tokens.subList(from, Math.min(tokens.size(), from + MAX_TOKENS_PER_CALL));
                BatchResponse response = circuitBreaker.executeCheckedSupplier(
                        () -> messaging.sendEach(build(message, chunk)));
                List<SendResponse> responses = response.getResponses();
                for (int i = 0; i < responses.size() && i < chunk.size(); i++) {
                    SendResponse r = responses.get(i);
                    if (r.isSuccessful()) {
                        delivered++;
                    } else if (isStale(r.getException())) {
                        stale.add(chunk.get(i));
                    }
                }
            }

            if (!stale.isEmpty() || delivered > 0) {
                int pushed = delivered;
                transactionTemplate.executeWithoutResult(status -> {
                    if (!stale.isEmpty()) tokenRepository.deleteByTokenIn(stale);
                    if (pushed > 0) notificationRepository.markPushed(message.notificationId());
                });
            }
            log.debug("Push for notification {}: {} of {} device(s) accepted, {} stale token(s) removed",
                    message.notificationId(), delivered, tokens.size(), stale.size());
            return delivered;
        } catch (CallNotPermittedException e) {
            log.warn("FCM circuit breaker open; push for notification {} skipped", message.notificationId());
            return 0;
        } catch (Error e) {
            throw e;
        } catch (Throwable e) {
            log.warn("Push for notification {} failed: {}", message.notificationId(), describe(e));
            return 0;
        }
    }

    /**
     * One message per device token, same content (FCM {@code sendEach}). {@code setToken} is
     * deprecated in firebase-admin 9.x in favour of installation ids, but the web and mobile
     * SDKs still hand out registration tokens, which only {@code setToken} addresses.
     */
    @SuppressWarnings("deprecation")
    static List<Message> build(PushMessage message, List<String> tokens) {
        Map<String, String> data = new LinkedHashMap<>();
        if (message.data() != null) {
            message.data().forEach((k, v) -> {
                if (k != null && v != null) data.put(k, v.toString());
            });
        }
        data.put("notificationId", message.notificationId().toString());
        data.put("type", message.type());
        if (message.title() != null) data.put("title", message.title());
        if (message.body() != null) data.put("body", message.body());

        return tokens.stream().map(token -> Message.builder()
                .setToken(token)
                .setNotification(com.google.firebase.messaging.Notification.builder()
                        .setTitle(message.title())
                        .setBody(message.body())
                        .build())
                .putAllData(data)
                .setAndroidConfig(AndroidConfig.builder()
                        .setPriority(AndroidConfig.Priority.HIGH)
                        .setCollapseKey(message.type())
                        .build())
                .setApnsConfig(ApnsConfig.builder()
                        .setAps(Aps.builder()
                                .setBadge((int) Math.min(Integer.MAX_VALUE, Math.max(0, message.unreadCount())))
                                .setSound("default")
                                .build())
                        .build())
                .setWebpushConfig(WebpushConfig.builder()
                        .putHeader("Urgency", "high")
                        .build())
                .build())
                .toList();
    }

    /**
     * Whether FCM's error means the token itself is unusable. INVALID_ARGUMENT is also returned
     * for a malformed message (payload too big, bad field), which says nothing about the token;
     * it only counts when the error is about the token: the message names the registration token
     * ("The registration token is not a valid FCM registration token") or the error details carry
     * a field violation on {@code message.token}.
     */
    static boolean isStale(FirebaseMessagingException e) {
        if (e == null || e.getMessagingErrorCode() == null) {
            return false;
        }
        if (STALE_TOKEN_ERRORS.contains(e.getMessagingErrorCode())) {
            return true;
        }
        return e.getMessagingErrorCode() == MessagingErrorCode.INVALID_ARGUMENT && isAboutTheToken(e);
    }

    private static boolean isAboutTheToken(FirebaseMessagingException e) {
        String message = e.getMessage();
        if (message != null && message.toLowerCase(Locale.ROOT).contains("registration token")) {
            return true;
        }
        IncomingHttpResponse response = e.getHttpResponse();
        String content = response == null ? null : response.getContent();
        return content != null && content.contains("\"message.token\"");
    }

    private static String describe(Throwable e) {
        if (e instanceof FirebaseMessagingException fme && fme.getMessagingErrorCode() != null) {
            return fme.getMessagingErrorCode().name();
        }
        return e.getClass().getSimpleName();
    }
}
