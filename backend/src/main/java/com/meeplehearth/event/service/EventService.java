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
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
public class EventService {

    private final EventRepository eventRepository;
    private final EventParticipantRepository participantRepository;
    private final UserRepository userRepository;
    private final GameRepository gameRepository;

    public EventService(EventRepository eventRepository,
                        EventParticipantRepository participantRepository,
                        UserRepository userRepository,
                        GameRepository gameRepository) {
        this.eventRepository = eventRepository;
        this.participantRepository = participantRepository;
        this.userRepository = userRepository;
        this.gameRepository = gameRepository;
    }

    // -------------------------------------------------------------------------
    // List
    // -------------------------------------------------------------------------

    public List<EventResponse> getUpcomingEvents(UUID currentUserId) {
        return eventRepository.findUpcomingEvents(Instant.now()).stream()
                .map(e -> toResponse(e, currentUserId))
                .toList();
    }

    public List<EventResponse> getMyEvents(UUID userId) {
        return participantRepository.findAcceptedByUserId(userId).stream()
                .map(ep -> toResponse(ep.getEvent(), userId))
                .toList();
    }

    // -------------------------------------------------------------------------
    // Single event
    // -------------------------------------------------------------------------

    public EventResponse getEvent(UUID eventId, UUID currentUserId) {
        return toResponse(findActiveEvent(eventId), currentUserId);
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
        Event event = findActiveEvent(eventId);
        if (!event.getHost().getId().equals(userId)) {
            throw ApiException.forbidden("FORBIDDEN", "Only the host can update this event");
        }

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
        Event event = findActiveEvent(eventId);
        if (!event.getHost().getId().equals(userId)) {
            throw ApiException.forbidden("FORBIDDEN", "Only the host can delete this event");
        }
        event.setDeletedAt(Instant.now());
        event.setStatus(Event.EventStatus.CANCELLED);
        eventRepository.save(event);
    }

    // -------------------------------------------------------------------------
    // RSVP
    // -------------------------------------------------------------------------

    @Transactional
    public EventResponse rsvp(UUID userId, UUID eventId, String statusStr) {
        Event event = findActiveEvent(eventId);
        User user = userRepository.findById(userId)
                .orElseThrow(() -> ApiException.notFound("User not found"));

        EventParticipant.RsvpStatus newStatus = EventParticipant.RsvpStatus.valueOf(statusStr.toUpperCase());

        Optional<EventParticipant> existing = participantRepository.findByEventIdAndUserId(eventId, userId);

        if (existing.isPresent()) {
            existing.get().setStatus(newStatus);
            participantRepository.save(existing.get());
        } else {
            // Capacity check (only for ACCEPTED)
            if (newStatus == EventParticipant.RsvpStatus.ACCEPTED) {
                int acceptedCount = participantRepository.countAcceptedByEventId(eventId);
                if (acceptedCount >= event.getMaxParticipants()) {
                    throw ApiException.conflict("EVENT_FULL", "This event is already full");
                }
            }
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

    private EventResponse toResponse(Event event, UUID currentUserId) {
        int count = participantRepository.countAcceptedByEventId(event.getId());
        String myRsvp = currentUserId == null ? null :
                participantRepository.findByEventIdAndUserId(event.getId(), currentUserId)
                        .map(ep -> ep.getStatus().name())
                        .orElse(null);
        return EventResponse.from(event, count, myRsvp);
    }
}
