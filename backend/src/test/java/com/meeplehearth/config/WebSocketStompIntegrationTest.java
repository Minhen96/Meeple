package com.meeplehearth.config;

import com.meeplehearth.auth.util.JwtUtil;
import com.meeplehearth.notification.entity.Notification.NotificationType;
import com.meeplehearth.notification.service.NotificationService;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import com.meeplehearth.user.service.UserService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.messaging.converter.CompositeMessageConverter;
import org.springframework.messaging.converter.MappingJackson2MessageConverter;
import org.springframework.messaging.converter.StringMessageConverter;
import org.springframework.messaging.simp.stomp.StompFrameHandler;
import org.springframework.messaging.simp.stomp.StompHeaders;
import org.springframework.messaging.simp.stomp.StompSession;
import org.springframework.messaging.simp.stomp.StompSessionHandlerAdapter;
import org.springframework.web.socket.WebSocketHttpHeaders;
import org.springframework.web.socket.client.standard.StandardWebSocketClient;
import org.springframework.web.socket.messaging.WebSocketStompClient;

import java.lang.reflect.Type;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Real STOMP-over-WebSocket clients against the running server: handshake cookie capture,
 * CONNECT authentication, SUBSCRIBE authorization, per-user notification routing and the
 * closing of live sockets when a user's sessions are revoked.
 * <p>
 * The server handles requests on its own threads, so rows are committed; every user created
 * here is deleted afterwards (dependent rows cascade).
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class WebSocketStompIntegrationTest {

    private static final String ORIGIN = "http://localhost:5173";
    private static final long TIMEOUT_S = 10;

    @LocalServerPort private int port;
    @Autowired private UserRepository userRepository;
    @Autowired private UserService userService;
    @Autowired private NotificationService notificationService;
    @Autowired private JwtUtil jwtUtil;
    @Autowired private JdbcTemplate jdbc;

    private WebSocketStompClient client;
    private final List<UUID> createdUsers = new ArrayList<>();
    private final List<StompSession> sessions = new ArrayList<>();

    @BeforeEach
    void setUpClient() {
        client = new WebSocketStompClient(new StandardWebSocketClient());
        client.setMessageConverter(new CompositeMessageConverter(
                List.of(new StringMessageConverter(), new MappingJackson2MessageConverter())));
    }

    @AfterEach
    void cleanUp() {
        try {
            for (StompSession session : sessions) {
                try {
                    session.disconnect();
                } catch (RuntimeException alreadyClosedByServer) {
                    // Expected for sessions the server rejected and is closing
                }
            }
            client.stop();
        } finally {
            for (UUID id : createdUsers) {
                jdbc.update("DELETE FROM users WHERE id = ?", id);
            }
        }
    }

    private User createUser() {
        String name = "ws" + UUID.randomUUID().toString().replace("-", "").substring(0, 12);
        User user = new User();
        user.setUsername(name);
        user.setEmail(name + "@example.test");
        user.setEmailVerified(true);
        User saved = userRepository.save(user);
        createdUsers.add(saved.getId());
        return saved;
    }

    /** Records frames and errors a session handler receives. */
    private static final class RecordingHandler extends StompSessionHandlerAdapter {
        final BlockingQueue<String> errors = new LinkedBlockingQueue<>();
        final CompletableFuture<Throwable> transportError = new CompletableFuture<>();

        @Override
        public Type getPayloadType(StompHeaders headers) {
            return String.class;
        }

        @Override
        public void handleFrame(StompHeaders headers, Object payload) {
            errors.add(String.valueOf(headers.getFirst("message")));
        }

        @Override
        public void handleTransportError(StompSession session, Throwable exception) {
            transportError.complete(exception);
        }
    }

    private CompletableFuture<StompSession> connect(String cookieToken, String bearerToken, RecordingHandler handler) {
        WebSocketHttpHeaders handshake = new WebSocketHttpHeaders();
        handshake.setOrigin(ORIGIN);
        if (cookieToken != null) {
            handshake.add("Cookie", "theme=dark; access_token=" + cookieToken);
        }
        StompHeaders connectHeaders = new StompHeaders();
        if (bearerToken != null) {
            connectHeaders.add("Authorization", "Bearer " + bearerToken);
        }
        return client.connectAsync("ws://localhost:" + port + "/ws", handshake, connectHeaders, handler);
    }

    private StompSession connected(String cookieToken, String bearerToken, RecordingHandler handler) throws Exception {
        StompSession session = connect(cookieToken, bearerToken, handler).get(TIMEOUT_S, TimeUnit.SECONDS);
        sessions.add(session);
        return session;
    }

    private static StompFrameHandler collectingInto(BlockingQueue<Map<String, Object>> queue) {
        return new StompFrameHandler() {
            @Override
            public Type getPayloadType(StompHeaders headers) {
                return Map.class;
            }

            @Override
            @SuppressWarnings("unchecked")
            public void handleFrame(StompHeaders headers, Object payload) {
                queue.add((Map<String, Object>) payload);
            }
        };
    }

    /** Subscriptions are processed asynchronously: keep notifying until one arrives. */
    private Map<String, Object> notifyUntilReceived(UUID recipient, BlockingQueue<Map<String, Object>> inbox)
            throws Exception {
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(TIMEOUT_S);
        while (System.nanoTime() < deadline) {
            notificationService.send(recipient, NotificationType.FRIEND_REQUEST, null, null, "USER");
            Map<String, Object> received = inbox.poll(250, TimeUnit.MILLISECONDS);
            if (received != null) {
                return received;
            }
        }
        throw new AssertionError("No notification received over WebSocket");
    }

    @Test
    void cookieAuthenticatedClientReceivesOnlyItsOwnNotifications() throws Exception {
        User alice = createUser();
        User bob = createUser();
        BlockingQueue<Map<String, Object>> aliceInbox = new LinkedBlockingQueue<>();
        BlockingQueue<Map<String, Object>> bobInbox = new LinkedBlockingQueue<>();

        // Web clients authenticate with the access_token cookie captured during the handshake
        StompSession aliceSession = connected(jwtUtil.generateAccessToken(alice.getId(), 0), null, new RecordingHandler());
        // Mobile clients send the token in the STOMP CONNECT header
        StompSession bobSession = connected(null, jwtUtil.generateAccessToken(bob.getId(), 0), new RecordingHandler());
        aliceSession.subscribe("/user/queue/notifications", collectingInto(aliceInbox));
        bobSession.subscribe("/user/queue/notifications", collectingInto(bobInbox));

        Map<String, Object> received = notifyUntilReceived(alice.getId(), aliceInbox);

        // Frame shape (docs/GAP_ANALYSIS.md section 6.3): {notification: NotificationDto, unreadCount}
        assertThat(received).containsKey("unreadCount");
        @SuppressWarnings("unchecked")
        Map<String, Object> notification = (Map<String, Object>) received.get("notification");
        assertThat(notification).containsEntry("type", "FRIEND_REQUEST").containsEntry("read", false);
        assertThat(notification.get("id")).isNotNull();
        // Bob is connected and subscribed to the same destination, but it resolves to his own queue
        assertThat(bobInbox.poll(500, TimeUnit.MILLISECONDS)).isNull();
        assertThat(notifyUntilReceived(bob.getId(), bobInbox).get("notification"))
                .asInstanceOf(org.assertj.core.api.InstanceOfAssertFactories.MAP)
                .containsEntry("type", "FRIEND_REQUEST");
    }

    @Test
    void connectWithoutAValidTokenIsRefused() {
        User user = createUser();

        for (String token : new String[]{null, "garbage", jwtUtil.generateAccessToken(user.getId(), 5)}) {
            RecordingHandler handler = new RecordingHandler();
            CompletableFuture<StompSession> future = connect(token, null, handler);

            assertThatThrownBy(() -> future.get(TIMEOUT_S, TimeUnit.SECONDS))
                    .as("token %s", token)
                    .isInstanceOf(ExecutionException.class);
        }
    }

    @Test
    void subscribingToAnotherUsersQueueClosesTheSession() throws Exception {
        User user = createUser();
        User victim = createUser();
        RecordingHandler handler = new RecordingHandler();
        StompSession session = connected(jwtUtil.generateAccessToken(user.getId(), 0), null, handler);

        session.subscribe("/user/" + victim.getId() + "/queue/notifications",
                collectingInto(new LinkedBlockingQueue<>()));

        // The server answers with an ERROR frame and closes the socket. The frame may be dropped
        // when the close wins the race, so the close itself is the reliable signal.
        assertThat(handler.transportError.get(TIMEOUT_S, TimeUnit.SECONDS)).isNotNull();
        assertThat(session.isConnected()).isFalse();
        assertThat(handler.errors).allMatch("Subscription to this destination is not allowed"::equals);
    }

    @Test
    void deletingTheAccountClosesItsOpenSockets() throws Exception {
        User user = createUser();
        RecordingHandler handler = new RecordingHandler();
        BlockingQueue<Map<String, Object>> inbox = new LinkedBlockingQueue<>();
        StompSession session = connected(jwtUtil.generateAccessToken(user.getId(), 0), null, handler);
        session.subscribe("/user/queue/notifications", collectingInto(inbox));
        notifyUntilReceived(user.getId(), inbox);

        // Commits in its own transaction; the revocation listener runs after the commit
        userService.deleteMe(user.getId());

        assertThat(handler.transportError.get(TIMEOUT_S, TimeUnit.SECONDS)).isNotNull();
        assertThat(session.isConnected()).isFalse();
    }

    @Test
    void sendingToBrokerDestinationsIsRefused() throws Exception {
        User user = createUser();
        RecordingHandler handler = new RecordingHandler();
        StompSession session = connected(jwtUtil.generateAccessToken(user.getId(), 0), null, handler);

        StompHeaders headers = new StompHeaders();
        headers.setDestination("/topic/how-to-play/" + UUID.randomUUID());
        session.send(headers, "spoofed progress");

        assertThat(handler.transportError.get(TIMEOUT_S, TimeUnit.SECONDS)).isNotNull();
        assertThat(session.isConnected()).isFalse();
        assertThat(handler.errors).allMatch("Sending to this destination is not allowed"::equals);
    }
}
