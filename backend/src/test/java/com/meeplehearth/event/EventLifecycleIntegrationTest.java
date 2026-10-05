package com.meeplehearth.event;

import com.meeplehearth.common.event.UserSoftDeletedEvent;
import com.meeplehearth.event.service.EventJobs;
import com.meeplehearth.event.service.EventLifecycleService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.MediaType;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Reminder and auto-complete jobs (real Redis lock, real Postgres) and account-deletion cleanup. */
class EventLifecycleIntegrationTest extends EventIntegrationTestBase {

    @Autowired private EventLifecycleService lifecycleService;
    @Autowired private EventJobs eventJobs;
    @Autowired private StringRedisTemplate redis;
    @Autowired private ApplicationEventPublisher publisher;
    @Autowired private PlatformTransactionManager transactionManager;

    @AfterEach
    void releaseLocks() {
        redis.delete("lock:event_auto_complete");
        redis.delete("lock:event_reminder");
    }

    // -------------------------------------------------------------------------
    // Auto-complete
    // -------------------------------------------------------------------------

    @Test
    void autoCompleteCompletesLiveEventsTwelveHoursAfterStartAndNotifiesHost() {
        UUID host = user();
        Instant now = Instant.now();
        UUID due = event(host, "PUBLIC", now.minus(13, ChronoUnit.HOURS), 8);
        UUID dueFull = event(host, "FRIENDS", now.minus(2, ChronoUnit.DAYS), 2);
        jdbc.update("UPDATE events SET status = 'FULL' WHERE id = ?", dueFull);
        UUID tooRecent = event(host, "PUBLIC", now.minus(11, ChronoUnit.HOURS), 8);
        UUID cancelled = event(host, "PUBLIC", now.minus(13, ChronoUnit.HOURS), 8);
        jdbc.update("UPDATE events SET status = 'CANCELLED', deleted_at = now() WHERE id = ?", cancelled);

        assertThat(lifecycleService.completeDueEvents(now)).isGreaterThanOrEqualTo(2);

        assertThat(eventStatus(due)).isEqualTo("COMPLETED");
        assertThat(eventStatus(dueFull)).isEqualTo("COMPLETED");
        assertThat(eventStatus(tooRecent)).isEqualTo("OPEN");
        assertThat(eventStatus(cancelled)).isEqualTo("CANCELLED");
        assertThat(notifications(host, "EVENT_COMPLETED", due)).isEqualTo(1);
        assertThat(notifications(host, "EVENT_COMPLETED", tooRecent)).isZero();
        assertThat(liveUpdates(due)).singleElement()
                .satisfies(update -> assertThat(update.status()).isEqualTo("COMPLETED"));

        // Running again does nothing for already completed events
        lifecycleService.completeDueEvents(now);
        assertThat(notifications(host, "EVENT_COMPLETED", due)).isEqualTo(1);
    }

    @Test
    void autoCompleteJobRunsUnderLockAndSkipsWhileAnotherInstanceHoldsIt() {
        UUID host = user();
        UUID due = event(host, "PUBLIC", Instant.now().minus(1, ChronoUnit.DAYS), 8);

        redis.opsForValue().set("lock:event_auto_complete", "other-instance", Duration.ofMinutes(1));
        eventJobs.autoCompleteEvents();
        assertThat(eventStatus(due)).isEqualTo("OPEN");
        assertThat(redis.opsForValue().get("lock:event_auto_complete")).isEqualTo("other-instance");

        redis.delete("lock:event_auto_complete");
        eventJobs.autoCompleteEvents();
        assertThat(eventStatus(due)).isEqualTo("COMPLETED");
        assertThat(redis.hasKey("lock:event_auto_complete")).isFalse();
    }

    // -------------------------------------------------------------------------
    // Reminder
    // -------------------------------------------------------------------------

    @Test
    void reminderFiresOnceForAcceptedParticipants() {
        UUID host = user();
        UUID going = user();
        UUID invited = user();
        UUID left = user();
        Instant now = Instant.now();
        UUID inWindow = event(host, "PUBLIC", now.plus(24, ChronoUnit.HOURS), 8);
        participant(inWindow, going, "ACCEPTED");
        participant(inWindow, invited, "INVITED");
        participant(inWindow, left, "LEFT");
        UUID tooFar = event(host, "PUBLIC", now.plus(26, ChronoUnit.HOURS), 8);
        UUID completed = event(host, "PUBLIC", now.plus(24, ChronoUnit.HOURS), 8);
        jdbc.update("UPDATE events SET status = 'COMPLETED' WHERE id = ?", completed);

        assertThat(lifecycleService.sendDueReminders(now)).isGreaterThanOrEqualTo(1);

        assertThat(notifications(host, "EVENT_REMINDER", inWindow)).isEqualTo(1);
        assertThat(notifications(going, "EVENT_REMINDER", inWindow)).isEqualTo(1);
        assertThat(notifications(invited, "EVENT_REMINDER", inWindow)).isZero();
        assertThat(notifications(left, "EVENT_REMINDER", inWindow)).isZero();
        assertThat(count("SELECT COUNT(*) FROM events WHERE id = ? AND reminder_sent", inWindow)).isEqualTo(1);
        assertThat(notifications(host, "EVENT_REMINDER", tooFar)).isZero();
        assertThat(notifications(host, "EVENT_REMINDER", completed)).isZero();

        // Fires once: an hour later the event is still in the window but already reminded
        lifecycleService.sendDueReminders(now.plus(1, ChronoUnit.HOURS));
        assertThat(notifications(going, "EVENT_REMINDER", inWindow)).isEqualTo(1);

        // The job wrapper takes and releases the lock
        eventJobs.sendReminders();
        assertThat(redis.hasKey("lock:event_reminder")).isFalse();
    }

    @Test
    void eventCreatedLessThan24hAheadNeverGetsAReminder() throws Exception {
        UUID host = user();
        Instant soon = Instant.now().plus(23, ChronoUnit.HOURS).plus(30, ChronoUnit.MINUTES);
        String id = json(mvc.perform(post("/api/v1/events").with(as(host)).contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(eventBody("Last minute", soon, "PUBLIC", null, null))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.reminderSent").value(true))
                .andReturn()).get("data").get("id").asText();
        UUID eventId = UUID.fromString(id);

        lifecycleService.sendDueReminders(Instant.now());
        assertThat(notifications(host, "EVENT_REMINDER", eventId)).isZero();

        // Created more than 24h ahead: reminded once it enters the window
        Instant later = Instant.now().plus(24, ChronoUnit.HOURS).plus(30, ChronoUnit.MINUTES);
        UUID normal = UUID.fromString(json(mvc.perform(post("/api/v1/events").with(as(host))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(eventBody("Planned", later, "PUBLIC", null, null))))
                .andExpect(jsonPath("$.data.reminderSent").value(false))
                .andReturn()).get("data").get("id").asText());
        lifecycleService.sendDueReminders(Instant.now());
        assertThat(notifications(host, "EVENT_REMINDER", normal)).isEqualTo(1);
    }

    // -------------------------------------------------------------------------
    // Account deletion
    // -------------------------------------------------------------------------

    @Test
    void softDeletedUserLosesPendingInvitesToUpcomingEventsOnly() {
        UUID host = user();
        UUID deleted = user();
        UUID upcomingInvite = event(host, "INVITE_ONLY", Instant.now().plus(2, ChronoUnit.DAYS), 8);
        UUID upcomingAccepted = event(host, "PUBLIC", Instant.now().plus(2, ChronoUnit.DAYS), 8);
        UUID pastInvite = event(host, "INVITE_ONLY", Instant.now().minus(2, ChronoUnit.DAYS), 8);
        participant(upcomingInvite, deleted, "INVITED");
        participant(upcomingAccepted, deleted, "ACCEPTED");
        participant(pastInvite, deleted, "INVITED");

        new TransactionTemplate(transactionManager).executeWithoutResult(status -> {
            jdbc.update("UPDATE users SET deleted_at = now() WHERE id = ?", deleted);
            publisher.publishEvent(new UserSoftDeletedEvent(deleted));
        });

        assertThat(count("SELECT COUNT(*) FROM event_participants WHERE event_id = ? AND user_id = ?",
                upcomingInvite, deleted)).isZero();
        assertThat(participantStatus(upcomingAccepted, deleted)).isEqualTo("ACCEPTED");
        assertThat(participantStatus(pastInvite, deleted)).isEqualTo("INVITED");
    }

    @Test
    void rolledBackDeletionKeepsInvites() {
        UUID host = user();
        UUID user = user();
        UUID eventId = event(host, "INVITE_ONLY", Instant.now().plus(2, ChronoUnit.DAYS), 8);
        participant(eventId, user, "INVITED");

        new TransactionTemplate(transactionManager).executeWithoutResult(status -> {
            publisher.publishEvent(new UserSoftDeletedEvent(user));
            status.setRollbackOnly();
        });

        assertThat(participantStatus(eventId, user)).isEqualTo("INVITED");
    }
}
