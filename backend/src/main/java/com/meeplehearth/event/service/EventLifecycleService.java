package com.meeplehearth.event.service;

import com.meeplehearth.common.event.UserHardDeletedEvent;
import com.meeplehearth.common.event.UserSoftDeletedEvent;
import com.meeplehearth.event.entity.Event;
import com.meeplehearth.event.repository.EventParticipantRepository;
import com.meeplehearth.event.repository.EventRepository;
import com.meeplehearth.event.service.EventLiveUpdatePublisher.EventChanged;
import com.meeplehearth.notification.entity.Notification.NotificationType;
import com.meeplehearth.notification.service.NotificationService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Duration;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Time-driven event transitions run by {@link EventJobs} (FEATURES sections 4.4 and 4.5), and
 * event cleanup when an account is soft-deleted. Each event is processed in its own transaction
 * with a conditional UPDATE as the claim, so one failure only skips that event and an event is
 * never completed or reminded twice, even if two runs overlap.
 */
@Service
public class EventLifecycleService {

    private static final Logger log = LoggerFactory.getLogger(EventLifecycleService.class);

    /** Live events are completed this long after their start time. */
    static final Duration AUTO_COMPLETE_AFTER = Duration.ofHours(12);
    /** Reminder window: events starting 23–25h from now (hourly job, so each event is seen once or twice). */
    static final Duration REMINDER_WINDOW_START = Duration.ofHours(23);
    static final Duration REMINDER_WINDOW_END = Duration.ofHours(25);

    private final EventRepository eventRepository;
    private final EventParticipantRepository participantRepository;
    private final NotificationService notificationService;
    private final ApplicationEventPublisher eventPublisher;
    private final TransactionTemplate transactionTemplate;

    public EventLifecycleService(EventRepository eventRepository,
                                 EventParticipantRepository participantRepository,
                                 NotificationService notificationService,
                                 ApplicationEventPublisher eventPublisher,
                                 PlatformTransactionManager transactionManager) {
        this.eventRepository = eventRepository;
        this.participantRepository = participantRepository;
        this.notificationService = notificationService;
        this.eventPublisher = eventPublisher;
        this.transactionTemplate = new TransactionTemplate(transactionManager);
    }

    /**
     * Marks OPEN/FULL events that started more than 12h before {@code now} as COMPLETED and sends
     * the host EVENT_COMPLETED ("Share your memories"). Returns the number completed.
     */
    public int completeDueEvents(Instant now) {
        int completed = 0;
        for (UUID eventId : eventRepository.findIdsDueForCompletion(now.minus(AUTO_COMPLETE_AFTER))) {
            try {
                Boolean done = transactionTemplate.execute(status -> {
                    if (eventRepository.completeIfLive(eventId, now) != 1) {
                        return false; // cancelled or completed since the id list was read
                    }
                    // No "share your memories" prompt when the host's account was deleted
                    eventRepository.findWithHostAndGameById(eventId)
                            .map(Event::hostIdOrNull)
                            .ifPresent(hostId -> notificationService.send(hostId, NotificationType.EVENT_COMPLETED,
                                    null, eventId, EventService.REFERENCE_TYPE));
                    eventPublisher.publishEvent(new EventChanged(eventId));
                    return true;
                });
                if (Boolean.TRUE.equals(done)) {
                    completed++;
                }
            } catch (RuntimeException e) {
                log.error("Failed to auto-complete event {}", eventId, e);
            }
        }
        return completed;
    }

    /**
     * Sends EVENT_REMINDER to every accepted participant (host included) of live events starting
     * 23–25h after {@code now} whose reminder has not gone out, and marks them reminded. Returns
     * the number of events reminded.
     */
    public int sendDueReminders(Instant now) {
        int reminded = 0;
        for (UUID eventId : eventRepository.findIdsDueForReminder(
                now.plus(REMINDER_WINDOW_START), now.plus(REMINDER_WINDOW_END))) {
            try {
                Boolean done = transactionTemplate.execute(status -> {
                    if (eventRepository.markReminderSent(eventId) != 1) {
                        return false; // another run claimed it
                    }
                    for (UUID recipient : participantRepository.findAcceptedUserIds(eventId)) {
                        notificationService.send(recipient, NotificationType.EVENT_REMINDER,
                                null, eventId, EventService.REFERENCE_TYPE);
                    }
                    return true;
                });
                if (Boolean.TRUE.equals(done)) {
                    reminded++;
                }
            } catch (RuntimeException e) {
                log.error("Failed to send reminders for event {}", eventId, e);
            }
        }
        return reminded;
    }

    /**
     * Account soft-deleted (GAP_ANALYSIS section 6.2): the user's pending invites to events that
     * have not started are removed. Runs after the deletion commits, in its own transaction.
     */
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void onUserSoftDeleted(UserSoftDeletedEvent event) {
        int removed = participantRepository.deletePendingInvitesForUser(event.userId(), Instant.now());
        log.info("Removed {} pending event invites of a deleted account", removed);
    }

    /**
     * Account hard-deleted (FEATURES_COMPLETE section 1.6): the host's upcoming live events are
     * cancelled (status CANCELLED plus soft delete, as if the host had cancelled them) and every
     * accepted participant gets EVENT_CANCELLED. Past and completed events are kept and their host
     * becomes "Deleted User" once the user row is removed ({@code host_id} is set to NULL, V60).
     *
     * <p>Runs synchronously inside the hard-delete transaction, before the user row is deleted, so
     * the host's events can still be found and the cancellation commits or rolls back with it.
     * Notifications carry no actor: the actor row is about to disappear.
     */
    @EventListener
    @Transactional
    public void onUserHardDeleted(UserHardDeletedEvent event) {
        UUID hostId = event.userId();
        Instant now = Instant.now();
        List<UUID> eventIds = eventRepository.findUpcomingLiveIdsHostedBy(hostId, now);
        if (eventIds.isEmpty()) {
            return;
        }
        // Recipients are read before the update: it clears the persistence context
        Map<UUID, List<UUID>> recipients = new LinkedHashMap<>();
        for (UUID eventId : eventIds) {
            recipients.put(eventId, participantRepository.findAcceptedUserIds(eventId));
        }
        eventRepository.cancelLive(eventIds, now);
        recipients.forEach((eventId, userIds) -> {
            for (UUID recipient : userIds) {
                if (!recipient.equals(hostId)) {
                    notificationService.send(recipient, NotificationType.EVENT_CANCELLED,
                            null, eventId, EventService.REFERENCE_TYPE);
                }
            }
            eventPublisher.publishEvent(new EventChanged(eventId));
        });
        // Write the notifications now, before the account's row is deleted by plain JDBC
        eventRepository.flush();
        log.info("Cancelled {} upcoming events of a permanently deleted account", eventIds.size());
    }
}
