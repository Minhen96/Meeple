package com.meeplehearth.event;

import com.fasterxml.jackson.databind.JsonNode;
import com.meeplehearth.common.event.ActivityRecordedEvent;
import com.meeplehearth.support.social.ApiIntegrationTestBase;
import com.meeplehearth.event.dto.EventLiveUpdate;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.SimpMessageHeaderAccessor;
import org.springframework.messaging.support.AbstractSubscribableChannel;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.test.context.event.ApplicationEvents;
import org.springframework.test.context.event.RecordApplicationEvents;

import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * Shared seeding and reading helpers for the events integration tests. Application events
 * published on the test thread (MockMvc runs there) are recorded, and messages sent to the STOMP
 * broker channel are captured so live updates on {@code /topic/events/{id}} can be verified.
 * Neither changes the Spring context, so these tests share the cached one with the other API tests.
 */
@RecordApplicationEvents
abstract class EventIntegrationTestBase extends ApiIntegrationTestBase {

    @Autowired protected ApplicationEvents applicationEvents;
    @Autowired @Qualifier("brokerChannel") private AbstractSubscribableChannel brokerChannel;

    private final List<Message<?>> brokerMessages = new CopyOnWriteArrayList<>();
    private final ChannelInterceptor capture = new ChannelInterceptor() {
        @Override
        public Message<?> preSend(Message<?> message, MessageChannel channel) {
            brokerMessages.add(message);
            return message;
        }
    };

    @BeforeEach
    void captureBrokerMessages() {
        brokerChannel.addInterceptor(capture);
    }

    @AfterEach
    void stopCapturingBrokerMessages() {
        brokerChannel.removeInterceptor(capture);
        brokerMessages.clear();
    }

    protected void clearLiveUpdates() {
        brokerMessages.clear();
    }

    /** Live updates broadcast on {@code /topic/events/{eventId}} since the last clear, in order. */
    protected List<EventLiveUpdate> liveUpdates(UUID eventId) {
        String destination = EventLiveUpdate.destination(eventId);
        List<EventLiveUpdate> out = new ArrayList<>();
        for (Message<?> message : brokerMessages) {
            if (destination.equals(SimpMessageHeaderAccessor.getDestination(message.getHeaders()))) {
                try {
                    out.add(objectMapper.readValue((byte[]) message.getPayload(), EventLiveUpdate.class));
                } catch (java.io.IOException e) {
                    throw new AssertionError("unreadable live update", e);
                }
            }
        }
        return out;
    }

    /** The last raw JSON payload broadcast on {@code /topic/events/{eventId}} since the last clear. */
    protected JsonNode lastLiveUpdateJson(UUID eventId) {
        String destination = EventLiveUpdate.destination(eventId);
        JsonNode last = null;
        for (Message<?> message : brokerMessages) {
            if (destination.equals(SimpMessageHeaderAccessor.getDestination(message.getHeaders()))) {
                try {
                    last = objectMapper.readTree((byte[]) message.getPayload());
                } catch (java.io.IOException e) {
                    throw new AssertionError("unreadable live update", e);
                }
            }
        }
        if (last == null) {
            throw new AssertionError("no live update for " + eventId);
        }
        return last;
    }

    protected static Map<String, Object> eventBody(String title, Instant scheduledAt, String visibility,
                                                   UUID gameId, Integer maxParticipants) {
        Map<String, Object> body = new HashMap<>();
        body.put("title", title);
        body.put("scheduledAt", scheduledAt.toString());
        body.put("visibility", visibility);
        body.put("gameId", gameId);
        body.put("maxParticipants", maxParticipants);
        return body;
    }

    /** Inserts an event (host auto-accepted) directly; reminder already sent unless set otherwise. */
    protected UUID event(UUID host, String visibility, Instant scheduledAt, int maxParticipants) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO events (id, host_id, title, scheduled_at, visibility, max_participants)"
                        + " VALUES (?, ?, ?, ?, ?, ?)",
                id, host, visibility + " night", ts(scheduledAt), visibility, maxParticipants);
        participant(id, host, "ACCEPTED");
        return id;
    }

    protected void participant(UUID eventId, UUID userId, String status) {
        jdbc.update("INSERT INTO event_participants (event_id, user_id, status) VALUES (?, ?, ?)",
                eventId, userId, status);
    }

    protected String participantStatus(UUID eventId, UUID userId) {
        return string("SELECT status FROM event_participants WHERE event_id = ? AND user_id = ?", eventId, userId);
    }

    protected String eventStatus(UUID eventId) {
        return string("SELECT status FROM events WHERE id = ?", eventId);
    }

    protected int notifications(UUID recipient, String type, UUID eventId) {
        return count("SELECT COUNT(*) FROM notifications WHERE recipient_id = ? AND type = ? AND reference_id = ?",
                recipient, type, eventId);
    }

    protected List<ActivityRecordedEvent> activities(UUID userId) {
        return applicationEvents.stream(ActivityRecordedEvent.class)
                .filter(a -> a.userId().equals(userId))
                .toList();
    }

    protected static List<UUID> ids(JsonNode response) {
        return idsOf(response.get("data"));
    }

    protected static List<UUID> idsOf(JsonNode array) {
        List<UUID> out = new ArrayList<>();
        array.forEach(n -> out.add(UUID.fromString(n.get("id").asText())));
        return out;
    }

    protected static JsonNode find(JsonNode array, UUID id) {
        for (JsonNode n : array) {
            if (n.get("id").asText().equals(id.toString())) {
                return n;
            }
        }
        throw new AssertionError("event " + id + " not in response");
    }
}
