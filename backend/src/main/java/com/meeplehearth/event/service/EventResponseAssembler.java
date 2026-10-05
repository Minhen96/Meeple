package com.meeplehearth.event.service;

import com.meeplehearth.event.dto.EventResponse;
import com.meeplehearth.event.dto.EventResponse.ParticipantInfo;
import com.meeplehearth.event.entity.Event;
import com.meeplehearth.event.entity.EventParticipant;
import com.meeplehearth.event.repository.EventParticipantRepository;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Builds {@link EventResponse}s for one viewer with a fixed number of queries whatever the list
 * size (no N+1): one GROUP BY for accepted counts, one for the viewer's own RSVPs and one for
 * the participant lists (users fetched in the same query). Events must have host and game loaded.
 */
@Component
public class EventResponseAssembler {

    private final EventParticipantRepository participantRepository;

    public EventResponseAssembler(EventParticipantRepository participantRepository) {
        this.participantRepository = participantRepository;
    }

    public EventResponse toResponse(Event event, UUID viewerId) {
        return toResponses(List.of(event), viewerId).get(0);
    }

    public List<EventResponse> toResponses(List<Event> events, UUID viewerId) {
        if (events.isEmpty()) {
            return List.of();
        }
        List<UUID> ids = events.stream().map(Event::getId).toList();

        Map<UUID, Long> counts = new HashMap<>();
        for (Object[] row : participantRepository.countAcceptedByEventIds(ids)) {
            counts.put((UUID) row[0], ((Number) row[1]).longValue());
        }

        Map<UUID, String> myRsvps = new HashMap<>();
        for (EventParticipant ep : participantRepository.findByUserIdAndEventIds(viewerId, ids)) {
            myRsvps.put(ep.getId().getEventId(), ep.getStatus().name());
        }

        Map<UUID, UUID> hostByEvent = new HashMap<>();
        events.forEach(e -> hostByEvent.put(e.getId(), e.getHost().getId()));
        Map<UUID, List<ParticipantInfo>> participants = new HashMap<>();
        for (EventParticipant ep : participantRepository.findForEventsVisibleTo(ids, viewerId)) {
            UUID eventId = ep.getId().getEventId();
            boolean viewerIsHost = viewerId.equals(hostByEvent.get(eventId));
            if (viewerIsHost || ep.getStatus() == EventParticipant.RsvpStatus.ACCEPTED) {
                participants.computeIfAbsent(eventId, k -> new ArrayList<>()).add(ParticipantInfo.from(ep));
            }
        }

        return events.stream()
                .map(e -> EventResponse.from(e,
                        counts.getOrDefault(e.getId(), 0L).intValue(),
                        myRsvps.get(e.getId()),
                        viewerId,
                        participants.getOrDefault(e.getId(), List.of())))
                .toList();
    }
}
