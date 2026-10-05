package com.meeplehearth.event;

import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.event.dto.CreateEventRequest;
import com.meeplehearth.event.entity.Event;
import com.meeplehearth.event.repository.EventParticipantRepository;
import com.meeplehearth.event.repository.EventRepository;
import com.meeplehearth.event.service.EventService;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.notification.service.NotificationService;
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

/** EventService paths the API cannot reach: the JWT filter already guarantees the caller exists. */
@ExtendWith(MockitoExtension.class)
class EventServiceEdgeCaseTest {

    @Mock EventRepository eventRepository;
    @Mock EventParticipantRepository participantRepository;
    @Mock UserRepository userRepository;
    @Mock GameRepository gameRepository;
    @Mock NotificationService notificationService;

    EventService service;
    final UUID ghost = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new EventService(eventRepository, participantRepository, userRepository,
                gameRepository, notificationService);
        when(userRepository.findById(ghost)).thenReturn(Optional.empty());
    }

    @Test
    void unknownCallerCannotCreateEvent() {
        CreateEventRequest req = new CreateEventRequest("Night", null, null,
                Instant.now().plusSeconds(3600), null, null, "PUBLIC");

        assertThatThrownBy(() -> service.createEvent(ghost, req))
                .isInstanceOfSatisfying(ApiException.class,
                        e -> assertThat(e.getStatus()).isEqualTo(HttpStatus.NOT_FOUND));
        verify(eventRepository, never()).save(any());
    }

    @Test
    void unknownCallerCannotRsvp() {
        UUID eventId = UUID.randomUUID();
        Event event = new Event();
        event.setId(eventId);
        when(eventRepository.findActiveByIdForUpdate(eventId)).thenReturn(Optional.of(event));
        when(eventRepository.isVisibleTo(eventId, ghost)).thenReturn(true);

        assertThatThrownBy(() -> service.rsvp(ghost, eventId, "ACCEPTED"))
                .isInstanceOfSatisfying(ApiException.class,
                        e -> assertThat(e.getStatus()).isEqualTo(HttpStatus.NOT_FOUND));
        verify(participantRepository, never()).save(any());
    }
}
