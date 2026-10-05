package com.meeplehearth.event.service;

import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.event.dto.CreateEventRequest;
import com.meeplehearth.event.dto.EventResponse;
import com.meeplehearth.event.entity.Event;
import com.meeplehearth.event.entity.EventParticipant;
import com.meeplehearth.event.entity.EventParticipantId;
import com.meeplehearth.event.repository.EventParticipantRepository;
import com.meeplehearth.event.repository.EventRepository;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.notification.entity.Notification;
import com.meeplehearth.notification.service.NotificationService;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

@Service
public class EventService {

    public static final int MAX_LIST_LIMIT = 100;

    private final EventRepository eventRepository;
    private final EventParticipantRepository participantRepository;
    private final UserRepository userRepository;
    private final GameRepository gameRepository;
    private final NotificationService notificationService;

    public EventService(EventRepository eventRepository,
                        EventParticipantRepository participantRepository,
                        UserRepository userRepository,
                        GameRepository gameRepository,
                        NotificationService notificationService) {
        this.eventRepository = eventRepository;
        this.participantRepository = participantRepository;
        this.userRepository = userRepository;
        this.gameRepository = gameRepository;
        this.notificationService = notificationService;
    }

    // -------------------------------------------------------------------------
    // List
    // -------------------------------------------------------------------------

    @Transactional(readOnly = true)
    public List<EventResponse> getUpcomingEvents(UUID currentUserId, int limit) {
        int capped = Math.max(1, Math.min(limit, MAX_LIST_LIMIT));
        List<Event> events = eventRepository.findUpcomingVisibleEvents(
                Instant.now(), currentUserId, PageRequest.of(0, capped));
        return toResponses(events, currentUserId);
    }

    @Transactional(readOnly = true)
    public List<EventResponse> getMyEvents(UUID userId) {
        return toResponses(eventRepository.findAcceptedVisibleByUserId(userId), userId);
    }

    // -------------------------------------------------------------------------
    // Single event
    // -------------------------------------------------------------------------

    @Transactional(readOnly = true)
    public EventResponse getEvent(UUID eventId, UUID currentUserId) {
        Event event = eventRepository.findVisibleById(eventId, currentUserId)
                .orElseThrow(() -> ApiException.notFound("EVENT_NOT_FOUND", "Event not found"));
        return toResponse(event, currentUserId);
    }

    // -------------------------------------------------------------------------
    // Create
    // -------------------------------------------------------------------------

    @Transactional
    public EventResponse createEvent(UUID userId, CreateEventRequest req) {
        User host = userRepository.findById(userId)
                .orElseThrow(() -> ApiException.notFound("User not found"));

        Event event = new Event();
        event.setHost(host);
        event.setTitle(req.title());
        event.setDescription(req.description());
        event.setLocation(req.location());
        event.setScheduledAt(req.scheduledAt());
        event.setMaxParticipants(req.maxParticipants() != null ? req.maxParticipants() : 8);
        event.setVisibility(Event.Visibility.valueOf(req.visibility()));

        if (req.gameId() != null) {
            gameRepository.findById(req.gameId()).ifPresent(event::setGame);
        }

        Event saved = eventRepository.save(event);

        // Host is automatically ACCEPTED
        EventParticipant hostParticipant = new EventParticipant(saved, host, EventParticipant.RsvpStatus.ACCEPTED);
        participantRepository.save(hostParticipant);

        return toResponse(saved, userId);
    }

    // -------------------------------------------------------------------------
    // Update
    // -------------------------------------------------------------------------

    @Transactional
    public EventResponse updateEvent(UUID userId, UUID eventId, CreateEventRequest req) {
        Event event = findHostedEvent(userId, eventId, "Only the host can update this event");

        if (req.title() != null)       event.setTitle(req.title());
        if (req.description() != null) event.setDescription(req.description());
        if (req.location() != null)    event.setLocation(req.location());
        if (req.scheduledAt() != null) event.setScheduledAt(req.scheduledAt());
        if (req.visibility() != null)  event.setVisibility(Event.Visibility.valueOf(req.visibility()));
        if (req.maxParticipants() != null) event.setMaxParticipants(req.maxParticipants());

        return toResponse(eventRepository.save(event), userId);
    }

    // -------------------------------------------------------------------------
    // Delete
    // -------------------------------------------------------------------------

    @Transactional
    public void deleteEvent(UUID userId, UUID eventId) {
        Event event = findHostedEvent(userId, eventId, "Only the host can delete this event");
        event.setDeletedAt(Instant.now());
        event.setStatus(Event.EventStatus.CANCELLED);
        eventRepository.save(event);
    }

    // -------------------------------------------------------------------------
    // RSVP
    // -------------------------------------------------------------------------

    @Transactional
    public EventResponse rsvp(UUID userId, UUID eventId, String statusStr) {
        // Lock the event row first so concurrent RSVPs are serialised for the capacity check
        Event event = eventRepository.findActiveByIdForUpdate(eventId)
                .orElseThrow(() -> ApiException.notFound("EVENT_NOT_FOUND", "Event not found"));
        // Not visible (incl. blocked by/blocking the host) → 404 so existence is not leaked
        if (!eventRepository.isVisibleTo(eventId, userId)) {
            throw ApiException.notFound("EVENT_NOT_FOUND", "Event not found");
        }
        User user = userRepository.findById(userId)
                .orElseThrow(() -> ApiException.notFound("User not found"));

        EventParticipant.RsvpStatus newStatus = EventParticipant.RsvpStatus.valueOf(statusStr.toUpperCase());

        Optional<EventParticipant> existing = participantRepository.findByEventIdAndUserId(eventId, userId);

        boolean alreadyAccepted = existing
                .map(ep -> ep.getStatus() == EventParticipant.RsvpStatus.ACCEPTED)
                .orElse(false);
        if (newStatus == EventParticipant.RsvpStatus.ACCEPTED && !alreadyAccepted) {
            int acceptedCount = participantRepository.countAcceptedByEventId(eventId);
            if (acceptedCount >= event.getMaxParticipants()) {
                throw ApiException.conflict("EVENT_FULL", "This event is already full");
            }
        }

        if (existing.isPresent()) {
            existing.get().setStatus(newStatus);
            participantRepository.save(existing.get());
        } else {
            participantRepository.save(new EventParticipant(event, user, newStatus));
        }

        // Update event status to FULL if needed
        int accepted = participantRepository.countAcceptedByEventId(eventId);
        if (accepted >= event.getMaxParticipants()) {
            event.setStatus(Event.EventStatus.FULL);
        } else if (event.getStatus() == Event.EventStatus.FULL) {
            event.setStatus(Event.EventStatus.OPEN);
        }
        eventRepository.save(event);

        // Notify host when someone accepts (not the host themselves)
        UUID hostId = event.getHost().getId();
        if (newStatus == EventParticipant.RsvpStatus.ACCEPTED && !userId.equals(hostId)) {
            notificationService.send(hostId, Notification.NotificationType.EVENT_RSVP, userId, eventId, "EVENT");
        }

        return toResponse(event, userId);
    }

    @Transactional
    public void leaveEvent(UUID userId, UUID eventId) {
        EventParticipantId pid = new EventParticipantId(eventId, userId);
        if (!participantRepository.existsById(pid)) {
            throw ApiException.notFound("RSVP_NOT_FOUND", "You have not RSVP'd to this event");
        }
        Event event = findActiveEvent(eventId);
        if (event.getHost().getId().equals(userId)) {
            throw ApiException.badRequest("HOST_CANNOT_LEAVE", "The host cannot leave their own event");
        }
        participantRepository.deleteById(pid);

        int accepted = participantRepository.countAcceptedByEventId(eventId);
        if (event.getStatus() == Event.EventStatus.FULL && accepted < event.getMaxParticipants()) {
            event.setStatus(Event.EventStatus.OPEN);
            eventRepository.save(event);
        }
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private Event findActiveEvent(UUID eventId) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> ApiException.notFound("EVENT_NOT_FOUND", "Event not found"));
        if (event.getDeletedAt() != null) {
            throw ApiException.notFound("EVENT_NOT_FOUND", "Event not found");
        }
        return event;
    }

    /**
     * Loads an event for a host-only mutation. Events the caller cannot see (including when
     * either side has blocked the other) are 404 so their existence is not leaked; 403 is only
     * returned when the caller can see the event but is not its host.
     */
    private Event findHostedEvent(UUID userId, UUID eventId, String forbiddenMessage) {
        Event event = eventRepository.findVisibleById(eventId, userId)
                .orElseThrow(() -> ApiException.notFound("EVENT_NOT_FOUND", "Event not found"));
        if (!event.getHost().getId().equals(userId)) {
            throw ApiException.forbidden("FORBIDDEN", forbiddenMessage);
        }
        return event;
    }

    private EventResponse toResponse(Event event, UUID currentUserId) {
        int count = participantRepository.countAcceptedByEventId(event.getId());
        String myRsvp = currentUserId == null ? null :
                participantRepository.findByEventIdAndUserId(event.getId(), currentUserId)
                        .map(ep -> ep.getStatus().name())
                        .orElse(null);
        return EventResponse.from(event, count, myRsvp);
    }

    /** Batch variant: one GROUP BY query for counts and one query for the caller's RSVPs. */
    private List<EventResponse> toResponses(List<Event> events, UUID currentUserId) {
        if (events.isEmpty()) {
            return List.of();
        }
        List<UUID> ids = events.stream().map(Event::getId).toList();

        Map<UUID, Long> counts = new HashMap<>();
        for (Object[] row : participantRepository.countAcceptedByEventIds(ids)) {
            counts.put((UUID) row[0], ((Number) row[1]).longValue());
        }

        Map<UUID, String> myRsvps = new HashMap<>();
        if (currentUserId != null) {
            for (EventParticipant ep : participantRepository.findByUserIdAndEventIds(currentUserId, ids)) {
                myRsvps.put(ep.getId().getEventId(), ep.getStatus().name());
            }
        }

        return events.stream()
                .map(e -> EventResponse.from(e,
                        counts.getOrDefault(e.getId(), 0L).intValue(),
                        myRsvps.get(e.getId())))
                .toList();
    }
}
