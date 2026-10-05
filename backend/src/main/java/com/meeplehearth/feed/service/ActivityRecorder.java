package com.meeplehearth.feed.service;

import com.meeplehearth.common.event.ActivityRecordedEvent;
import com.meeplehearth.common.event.UserHardDeletedEvent;
import com.meeplehearth.feed.entity.ActivityEvent;
import com.meeplehearth.feed.repository.ActivityEventRepository;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import java.time.Duration;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

/**
 * Turns {@link ActivityRecordedEvent}s published by the events and library packages into
 * {@code activity_events} rows once the publishing transaction commits, so a rolled-back action
 * never shows up in feeds. Failures are logged and never affect the publisher.
 *
 * <p>A repeated {@code collection_add} for the same game within 24 hours (toggling "owned" off and
 * on again) is recorded once.
 */
@Component
public class ActivityRecorder {

    private static final Logger log = LoggerFactory.getLogger(ActivityRecorder.class);

    static final Set<String> TYPES = Set.of(
            ActivityRecordedEvent.COLLECTION_ADD, ActivityRecordedEvent.EVENT_CREATED, ActivityRecordedEvent.EVENT_JOINED);
    static final Duration COLLECTION_ADD_DEDUP_WINDOW = Duration.ofHours(24);

    private final ActivityEventRepository activityEventRepository;
    private final UserRepository userRepository;
    private final FeedCache feedCache;

    public ActivityRecorder(ActivityEventRepository activityEventRepository,
                            UserRepository userRepository,
                            FeedCache feedCache) {
        this.activityEventRepository = activityEventRepository;
        this.userRepository = userRepository;
        this.feedCache = feedCache;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void onActivityRecorded(ActivityRecordedEvent event) {
        try {
            record(event);
        } catch (RuntimeException e) {
            log.warn("Could not record {} activity for user {}", event.type(), event.userId(), e);
        }
    }

    private void record(ActivityRecordedEvent event) {
        if (event.userId() == null || !TYPES.contains(event.type())) {
            log.warn("Ignoring activity of unknown type '{}'", event.type());
            return;
        }
        Optional<User> user = userRepository.findById(event.userId()).filter(u -> u.getDeletedAt() == null);
        if (user.isEmpty()) {
            return;
        }
        Map<String, Object> data = new LinkedHashMap<>();
        event.data().forEach((k, v) -> data.put(k, v == null ? null : normalize(v)));
        Instant at = event.at() != null ? event.at() : Instant.now();

        if (ActivityRecordedEvent.COLLECTION_ADD.equals(event.type()) && data.get("gameId") != null
                && activityEventRepository.existsRecentForGame(event.userId(), event.type(),
                String.valueOf(data.get("gameId")), at.minus(COLLECTION_ADD_DEDUP_WINDOW))) {
            return;
        }

        ActivityEvent row = new ActivityEvent();
        row.setUser(user.get());
        row.setType(event.type());
        row.setData(data);
        row.setCreatedAt(at);
        activityEventRepository.save(row);
        feedCache.invalidateAfterCommit(event.userId());
    }

    /**
     * Ids, timestamps and other scalars are stored as strings; JSON-native values (numbers,
     * booleans, strings, maps, lists) pass through.
     */
    private static Object normalize(Object value) {
        if (value instanceof Number || value instanceof Boolean || value instanceof String
                || value instanceof Map<?, ?> || value instanceof java.util.Collection<?>) {
            return value;
        }
        return value.toString();
    }

    /** Permanently removes the user's activity items when their account is hard-deleted. */
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void onUserHardDeleted(UserHardDeletedEvent event) {
        int removed = activityEventRepository.deleteByUserId(event.userId());
        log.info("Removed {} activity items of hard-deleted user {}", removed, event.userId());
    }
}
