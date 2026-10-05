package com.meeplehearth.event;

import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.event.dto.CreateEventRequest;
import com.meeplehearth.event.entity.Event;
import com.meeplehearth.event.repository.EventParticipantRepository;
import com.meeplehearth.event.repository.EventRepository;
import com.meeplehearth.event.service.EventResponseAssembler;
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
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** EventService paths the API cannot reach (the JWT filter and bean validation run first). */
@ExtendWith(MockitoExtension.class)
class EventServiceEdgeCaseTest {

    @Mock EventRepository eventRepository;
    @Mock EventParticipantRepository participantRepository;
    @Mock UserRepository userRepository;
    @Mock GameRepository gameRepository;
    @Mock NotificationService notificationService;
    @Mock EventResponseAssembler assembler;
    @Mock ApplicationEventPublisher eventPublisher;

    EventService service;
    final UUID ghost = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new EventService(eventRepository, participantRepository, userRepository,
                gameRepository, notificationService, assembler, eventPublisher);
    }

    @Test
    void unknownCallerCannotCreateEvent() {
        when(userRepository.findById(ghost)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.createEvent(ghost, request(Instant.now().plusSeconds(3600))))
                .isInstanceOfSatisfying(ApiException.class,
                        e -> assertThat(e.getStatus()).isEqualTo(HttpStatus.NOT_FOUND));
        verify(eventRepository, never()).save(any());
    }

    @Test
    void internallyBuiltRequestInThePastIsRejected() {
        User host = new User();
        host.setId(ghost);
        when(userRepository.findById(ghost)).thenReturn(Optional.of(host));

        assertThatThrownBy(() -> service.createEventFromMatch(ghost,
                request(Instant.now().minus(1, ChronoUnit.HOURS))))
                .isInstanceOfSatisfying(ApiException.class, e -> assertThat(e.getCode()).isEqualTo("INVALID_TIME"));
        verify(eventRepository, never()).save(any());
    }

    @Test
    void unknownCallerCannotRsvp() {
        UUID eventId = UUID.randomUUID();
        Event event = new Event();
        event.setId(eventId);
        when(eventRepository.findActiveByIdForUpdate(eventId)).thenReturn(Optional.of(event));
        when(eventRepository.isVisibleTo(eventId, ghost)).thenReturn(true);
        when(userRepository.findById(ghost)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.rsvp(ghost, eventId, "ACCEPTED"))
                .isInstanceOfSatisfying(ApiException.class,
                        e -> assertThat(e.getStatus()).isEqualTo(HttpStatus.NOT_FOUND));
        verify(participantRepository, never()).save(any());
    }

    @Test
    void calendarRangeMustBeOrderedAndAtMost62Days() {
        Instant from = Instant.parse("2026-10-01T00:00:00Z");
        assertThatThrownBy(() -> service.getCalendar(ghost, from, from))
                .isInstanceOfSatisfying(ApiException.class, e -> assertThat(e.getCode()).isEqualTo("INVALID_RANGE"));
        assertThatThrownBy(() -> service.getCalendar(ghost, from, from.plus(63, ChronoUnit.DAYS)))
                .isInstanceOfSatisfying(ApiException.class, e -> assertThat(e.getCode()).isEqualTo("INVALID_RANGE"));
    }

    @Test
    void malformedCommunityCursorIs400() {
        for (String cursor : List.of("%%%", "bm8tc2VwYXJhdG9y", "eHxub3QtYS11dWlk")) {
            assertThatThrownBy(() -> service.getCommunityEvents(ghost, null, cursor, 10))
                    .isInstanceOfSatisfying(ApiException.class,
                            e -> assertThat(e.getCode()).isEqualTo("INVALID_CURSOR"));
        }
    }

    private static CreateEventRequest request(Instant when) {
        return new CreateEventRequest("Night", null, null, null, when, null, null, "PUBLIC", null);
    }
}
