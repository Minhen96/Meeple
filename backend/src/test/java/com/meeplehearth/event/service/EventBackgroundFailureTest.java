package com.meeplehearth.event.service;

import com.meeplehearth.common.job.JobLock;
import com.meeplehearth.event.dto.EventLiveUpdate;
import com.meeplehearth.event.entity.Event;
import com.meeplehearth.event.repository.EventParticipantRepository;
import com.meeplehearth.event.repository.EventRepository;
import com.meeplehearth.notification.service.NotificationService;
import org.junit.jupiter.api.Test;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.data.redis.core.script.RedisScript;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.SimpleTransactionStatus;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Failure isolation in the event jobs and live updates (happy paths run in the integration tests). */
class EventBackgroundFailureTest {

    private final EventRepository eventRepository = mock(EventRepository.class);
    private final EventParticipantRepository participantRepository = mock(EventParticipantRepository.class);
    private final NotificationService notificationService = mock(NotificationService.class);
    private final ApplicationEventPublisher publisher = mock(ApplicationEventPublisher.class);
    private final PlatformTransactionManager txManager = mock(PlatformTransactionManager.class);

    private EventLifecycleService lifecycle() {
        when(txManager.getTransaction(any())).thenReturn(new SimpleTransactionStatus());
        return new EventLifecycleService(eventRepository, participantRepository, notificationService, publisher, txManager);
    }

    @Test
    void oneFailingEventDoesNotStopAutoCompletingTheOthers() {
        UUID broken = UUID.randomUUID();
        UUID fine = UUID.randomUUID();
        UUID raced = UUID.randomUUID();
        Instant now = Instant.now();
        when(eventRepository.findIdsDueForCompletion(any())).thenReturn(List.of(broken, fine, raced));
        when(eventRepository.completeIfLive(broken, now)).thenThrow(new IllegalStateException("deadlock"));
        when(eventRepository.completeIfLive(fine, now)).thenReturn(1);
        when(eventRepository.completeIfLive(raced, now)).thenReturn(0);
        when(eventRepository.findWithHostAndGameById(fine)).thenReturn(Optional.empty());

        assertThat(lifecycle().completeDueEvents(now)).isEqualTo(1);
    }

    @Test
    void oneFailingEventDoesNotStopRemindingTheOthers() {
        UUID broken = UUID.randomUUID();
        UUID fine = UUID.randomUUID();
        UUID claimed = UUID.randomUUID();
        UUID guest = UUID.randomUUID();
        when(eventRepository.findIdsDueForReminder(any(), any())).thenReturn(List.of(broken, fine, claimed));
        when(eventRepository.markReminderSent(broken)).thenThrow(new IllegalStateException("deadlock"));
        when(eventRepository.markReminderSent(fine)).thenReturn(1);
        when(eventRepository.markReminderSent(claimed)).thenReturn(0);
        when(participantRepository.findAcceptedUserIds(fine)).thenReturn(List.of(guest));

        assertThat(lifecycle().sendDueReminders(Instant.now())).isEqualTo(1);
        verify(participantRepository, never()).findAcceptedUserIds(claimed);
    }

    @Test
    void jobFailuresAreLoggedAndLocksReleased() {
        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        @SuppressWarnings("unchecked")
        ValueOperations<String, String> ops = mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(ops);
        when(ops.setIfAbsent(anyString(), anyString(), any(Duration.class))).thenReturn(true);
        EventLifecycleService service = mock(EventLifecycleService.class);
        doThrow(new IllegalStateException("db down")).when(service).completeDueEvents(any());
        doThrow(new IllegalStateException("db down")).when(service).sendDueReminders(any());
        EventJobs jobs = new EventJobs(service, new JobLock(redis));

        assertThatCode(jobs::autoCompleteEvents).doesNotThrowAnyException();
        assertThatCode(jobs::sendReminders).doesNotThrowAnyException();
        verify(redis).execute(any(RedisScript.class), eq(List.of("lock:event_auto_complete")), anyString());
        verify(redis).execute(any(RedisScript.class), eq(List.of("lock:event_reminder")), anyString());
    }

    @Test
    void liveUpdateFailureIsSwallowedAndMissingEventSendsNothing() {
        SimpMessagingTemplate template = mock(SimpMessagingTemplate.class);
        EventLiveUpdatePublisher livePublisher = new EventLiveUpdatePublisher(eventRepository, participantRepository, template);
        UUID gone = UUID.randomUUID();
        when(eventRepository.findWithHostAndGameById(gone)).thenReturn(Optional.empty());

        livePublisher.onEventChanged(new EventLiveUpdatePublisher.EventChanged(gone));
        verify(template, never()).convertAndSend(anyString(), any(Object.class));

        UUID eventId = UUID.randomUUID();
        Event event = new Event();
        event.setId(eventId);
        when(eventRepository.findWithHostAndGameById(eventId)).thenReturn(Optional.of(event));
        when(participantRepository.findAcceptedWithUsers(eventId)).thenReturn(List.of());
        doThrow(new IllegalStateException("broker down")).when(template)
                .convertAndSend(eq(EventLiveUpdate.destination(eventId)), any(Object.class));

        assertThatCode(() -> livePublisher.onEventChanged(new EventLiveUpdatePublisher.EventChanged(eventId)))
                .doesNotThrowAnyException();
    }
}
