package com.meeplehearth.event;

import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.event.dto.EventResponse;
import com.meeplehearth.event.entity.Event;
import com.meeplehearth.event.entity.EventParticipant;
import com.meeplehearth.event.repository.EventParticipantRepository;
import com.meeplehearth.event.repository.EventRepository;
import com.meeplehearth.event.service.EventService;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.notification.service.NotificationService;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class EventServiceRsvpTest {

    @Mock EventRepository eventRepository;
    @Mock EventParticipantRepository participantRepository;
    @Mock UserRepository userRepository;
    @Mock GameRepository gameRepository;
    @Mock NotificationService notificationService;

    EventService service;

    final UUID hostId = UUID.randomUUID();
    final UUID userId = UUID.randomUUID();
    final UUID eventId = UUID.randomUUID();
    Event event;
    User user;

    @BeforeEach
    void setUp() {
        service = new EventService(eventRepository, participantRepository, userRepository,
                gameRepository, notificationService);

        User host = new User();
        host.setId(hostId);
        user = new User();
        user.setId(userId);

        event = new Event();
        event.setId(eventId);
        event.setHost(host);
        event.setTitle("Catan Night");
        event.setScheduledAt(Instant.now().plusSeconds(86_400));
        event.setMaxParticipants(2);
        event.setVisibility(Event.Visibility.PUBLIC);
        event.setStatus(Event.EventStatus.FULL);
    }

    @Test
    void switchingDeclinedToAcceptedOnFullEventIsRejected() {
        EventParticipant declined = new EventParticipant(event, user, EventParticipant.RsvpStatus.DECLINED);
        when(eventRepository.findActiveByIdForUpdate(eventId)).thenReturn(Optional.of(event));
        when(eventRepository.isVisibleTo(eventId, userId)).thenReturn(true);
        when(userRepository.findById(userId)).thenReturn(Optional.of(user));
        when(participantRepository.findByEventIdAndUserId(eventId, userId)).thenReturn(Optional.of(declined));
        when(participantRepository.countAcceptedByEventId(eventId)).thenReturn(2);

        assertThatThrownBy(() -> service.rsvp(userId, eventId, "ACCEPTED"))
                .isInstanceOf(ApiException.class)
                .satisfies(e -> {
                    assertThat(((ApiException) e).getStatus()).isEqualTo(HttpStatus.CONFLICT);
                    assertThat(((ApiException) e).getCode()).isEqualTo("EVENT_FULL");
                });

        assertThat(declined.getStatus()).isEqualTo(EventParticipant.RsvpStatus.DECLINED);
        verify(participantRepository, never()).save(any());
        verify(notificationService, never()).send(any(), any(), any(), any(), any());
    }

    @Test
    void reAcceptingWhenAlreadyAcceptedOnFullEventIsAllowed() {
        EventParticipant accepted = new EventParticipant(event, user, EventParticipant.RsvpStatus.ACCEPTED);
        when(eventRepository.findActiveByIdForUpdate(eventId)).thenReturn(Optional.of(event));
        when(eventRepository.isVisibleTo(eventId, userId)).thenReturn(true);
        when(userRepository.findById(userId)).thenReturn(Optional.of(user));
        when(participantRepository.findByEventIdAndUserId(eventId, userId)).thenReturn(Optional.of(accepted));
        when(participantRepository.countAcceptedByEventId(eventId)).thenReturn(2);

        EventResponse response = service.rsvp(userId, eventId, "ACCEPTED");

        assertThat(response.myRsvp()).isEqualTo("ACCEPTED");
        assertThat(event.getStatus()).isEqualTo(Event.EventStatus.FULL);
    }

    @Test
    void rsvpToEventNotVisibleToCallerIs404() {
        when(eventRepository.findActiveByIdForUpdate(eventId)).thenReturn(Optional.of(event));
        when(eventRepository.isVisibleTo(eventId, userId)).thenReturn(false);

        assertThatThrownBy(() -> service.rsvp(userId, eventId, "ACCEPTED"))
                .isInstanceOf(ApiException.class)
                .satisfies(e -> assertThat(((ApiException) e).getStatus()).isEqualTo(HttpStatus.NOT_FOUND));
        verify(participantRepository, never()).save(any());
    }
}
