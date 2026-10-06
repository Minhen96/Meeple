package com.meeplehearth.event.service;

import com.meeplehearth.event.dto.EventLiveUpdate;
import com.meeplehearth.event.entity.Event;
import com.meeplehearth.event.repository.EventParticipantRepository;
import com.meeplehearth.event.repository.EventRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import java.util.Optional;
import java.util.UUID;

/**
 * Broadcasts {@link EventLiveUpdate} ({@code eventId, participantCount, status} only, never the
 * roster) on {@code /topic/events/{eventId}} once a change to the event's participants or status
 * has committed, so subscribers never see rolled-back state.
 * Who may subscribe is decided by the WebSocket subscribe interceptor (GAP_ANALYSIS section 6.3).
 * A failed broadcast is logged and never affects the change itself.
 */
@Component
public class EventLiveUpdatePublisher {

    private static final Logger log = LoggerFactory.getLogger(EventLiveUpdatePublisher.class);

    /** Published inside a transaction by {@link EventService} when an event's roster or status changes. */
    public record EventChanged(UUID eventId) {}

    private final EventRepository eventRepository;
    private final EventParticipantRepository participantRepository;
    private final SimpMessagingTemplate messagingTemplate;

    public EventLiveUpdatePublisher(EventRepository eventRepository,
                                    EventParticipantRepository participantRepository,
                                    SimpMessagingTemplate messagingTemplate) {
        this.eventRepository = eventRepository;
        this.participantRepository = participantRepository;
        this.messagingTemplate = messagingTemplate;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Transactional(propagation = Propagation.REQUIRES_NEW, readOnly = true)
    public void onEventChanged(EventChanged changed) {
        try {
            buildUpdate(changed.eventId()).ifPresent(update ->
                    messagingTemplate.convertAndSend(EventLiveUpdate.destination(update.eventId()), update));
        } catch (RuntimeException e) {
            log.warn("Failed to broadcast live update for event {}", changed.eventId(), e);
        }
    }

    Optional<EventLiveUpdate> buildUpdate(UUID eventId) {
        Optional<Event> event = eventRepository.findWithHostAndGameById(eventId);
        if (event.isEmpty()) {
            return Optional.empty();
        }
        int accepted = participantRepository.countAcceptedByEventId(eventId);
        return Optional.of(new EventLiveUpdate(eventId, accepted, event.get().getStatus().name()));
    }
}
