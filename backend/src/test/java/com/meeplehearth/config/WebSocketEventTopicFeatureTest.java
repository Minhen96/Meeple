package com.meeplehearth.config;

import com.meeplehearth.auth.util.JwtUtil;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.messaging.converter.StringMessageConverter;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.messaging.simp.stomp.StompFrameHandler;
import org.springframework.messaging.simp.stomp.StompHeaders;
import org.springframework.messaging.simp.stomp.StompSession;
import org.springframework.messaging.simp.stomp.StompSessionHandlerAdapter;
import org.springframework.web.socket.WebSocketHttpHeaders;
import org.springframework.web.socket.client.standard.StandardWebSocketClient;
import org.springframework.web.socket.messaging.WebSocketStompClient;

import java.lang.reflect.Type;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Real STOMP clients subscribing to {@code /topic/events/{eventId}}: allowed for viewers who can
 * see the event (host, public events), refused (ERROR + socket closed) for anyone else.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class WebSocketEventTopicFeatureTest {

    private static final String ORIGIN = "http://localhost:5173";
    private static final long TIMEOUT_S = 10;

    @LocalServerPort private int port;
    @Autowired private JwtUtil jwtUtil;
    @Autowired private JdbcTemplate jdbc;
    @Autowired private SimpMessagingTemplate messagingTemplate;

    private WebSocketStompClient client;
    private final List<UUID> users = new ArrayList<>();
    private final List<StompSession> sessions = new ArrayList<>();

    @BeforeEach
    void setUp() {
        client = new WebSocketStompClient(new StandardWebSocketClient());
        client.setMessageConverter(new StringMessageConverter());
    }

    @AfterEach
    void cleanUp() {
        for (StompSession session : sessions) {
            try {
                session.disconnect();
            } catch (RuntimeException alreadyClosed) {
                // closed by the server
            }
        }
        users.forEach(id -> com.meeplehearth.support.social.ApiIntegrationTestBase.deleteUserRows(jdbc, id));
    }

    private UUID user() {
        UUID id = UUID.randomUUID();
        String name = "wse" + id.toString().replace("-", "").substring(0, 12);
        jdbc.update("INSERT INTO users (id, username, email, email_verified) VALUES (?, ?, ?, true)",
                id, name, name + "@example.test");
        users.add(id);
        return id;
    }

    private UUID event(UUID host, String visibility) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO events (id, host_id, title, scheduled_at, visibility) VALUES (?, ?, 'WS night', ?, ?)",
                id, host, Timestamp.from(Instant.now().plusSeconds(86_400)), visibility);
        return id;
    }

    private static final class Recorder extends StompSessionHandlerAdapter {
        final CompletableFuture<Throwable> closed = new CompletableFuture<>();

        @Override
        public void handleTransportError(StompSession session, Throwable exception) {
            closed.complete(exception);
        }
    }

    private StompSession connect(UUID userId, Recorder recorder) throws Exception {
        WebSocketHttpHeaders handshake = new WebSocketHttpHeaders();
        handshake.setOrigin(ORIGIN);
        StompHeaders connect = new StompHeaders();
        connect.add("Authorization", "Bearer " + jwtUtil.generateAccessToken(userId, 0));
        StompSession session = client.connectAsync("ws://localhost:" + port + "/ws", handshake, connect, recorder)
                .get(TIMEOUT_S, TimeUnit.SECONDS);
        sessions.add(session);
        return session;
    }

    private static StompFrameHandler into(BlockingQueue<String> queue) {
        return new StompFrameHandler() {
            @Override
            public Type getPayloadType(StompHeaders headers) {
                return String.class;
            }

            @Override
            public void handleFrame(StompHeaders headers, Object payload) {
                queue.add(String.valueOf(payload));
            }
        };
    }

    @Test
    void viewerWhoCanSeeTheEventReceivesLiveUpdates() throws Exception {
        UUID host = user();
        UUID event = event(host, "INVITE_ONLY");
        BlockingQueue<String> inbox = new LinkedBlockingQueue<>();
        StompSession session = connect(host, new Recorder());
        session.subscribe("/topic/events/" + event, into(inbox));

        // The subscription is registered asynchronously: publish until it arrives
        String received = null;
        for (int i = 0; i < 50 && received == null; i++) {
            messagingTemplate.convertAndSend("/topic/events/" + event, "update-" + i);
            received = inbox.poll(100, TimeUnit.MILLISECONDS);
        }
        assertThat(received).startsWith("update-");
        assertThat(session.isConnected()).isTrue();
    }

    @Test
    void strangerCannotSubscribeToAPrivateEvent() throws Exception {
        UUID host = user();
        UUID stranger = user();
        UUID event = event(host, "INVITE_ONLY");
        Recorder recorder = new Recorder();
        StompSession session = connect(stranger, recorder);

        session.subscribe("/topic/events/" + event, into(new LinkedBlockingQueue<>()));

        assertThat(recorder.closed.get(TIMEOUT_S, TimeUnit.SECONDS)).isNotNull();
        assertThat(session.isConnected()).isFalse();
    }

    private boolean canSubscribe(UUID userId, UUID event) throws Exception {
        BlockingQueue<String> inbox = new LinkedBlockingQueue<>();
        Recorder recorder = new Recorder();
        StompSession session = connect(userId, recorder);
        session.subscribe("/topic/events/" + event, into(inbox));
        for (int i = 0; i < 50; i++) {
            if (recorder.closed.isDone()) {
                return false;
            }
            messagingTemplate.convertAndSend("/topic/events/" + event, "probe-" + i);
            if (inbox.poll(100, TimeUnit.MILLISECONDS) != null) {
                return true;
            }
        }
        return false;
    }

    private void participant(UUID event, UUID userId, String status) {
        jdbc.update("INSERT INTO event_participants (event_id, user_id, status) VALUES (?, ?, ?)", event, userId, status);
    }

    @Test
    void leftAndKickedParticipantsLoseTheLiveTopicOfPrivateEvents() throws Exception {
        UUID host = user();
        UUID declined = user();
        UUID left = user();
        UUID kickedFriend = user();
        UUID leftFriend = user();
        jdbc.update("INSERT INTO friend_requests (sender_id, receiver_id, status) VALUES (?, ?, 'ACCEPTED'),"
                + " (?, ?, 'ACCEPTED')", host, kickedFriend, leftFriend, host);
        UUID inviteOnly = event(host, "INVITE_ONLY");
        participant(inviteOnly, declined, "DECLINED");
        participant(inviteOnly, left, "LEFT");
        UUID friendsOnly = event(host, "FRIENDS");
        participant(friendsOnly, kickedFriend, "KICKED");
        participant(friendsOnly, leftFriend, "LEFT");
        UUID publicEvent = event(host, "PUBLIC");
        participant(publicEvent, left, "KICKED");

        assertThat(canSubscribe(declined, inviteOnly)).isTrue();
        assertThat(canSubscribe(left, inviteOnly)).isFalse();
        assertThat(canSubscribe(kickedFriend, friendsOnly)).isFalse();
        assertThat(canSubscribe(leftFriend, friendsOnly)).isTrue();
        assertThat(canSubscribe(left, publicEvent)).isTrue();
    }

    @Test
    void anyoneCanFollowAPublicEvent() throws Exception {
        UUID host = user();
        UUID viewer = user();
        UUID event = event(host, "PUBLIC");
        BlockingQueue<String> inbox = new LinkedBlockingQueue<>();
        StompSession session = connect(viewer, new Recorder());
        session.subscribe("/topic/events/" + event, into(inbox));

        String received = null;
        for (int i = 0; i < 50 && received == null; i++) {
            messagingTemplate.convertAndSend("/topic/events/" + event, "public-" + i);
            received = inbox.poll(100, TimeUnit.MILLISECONDS);
        }
        assertThat(received).startsWith("public-");
    }
}
