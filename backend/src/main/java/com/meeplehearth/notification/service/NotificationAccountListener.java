package com.meeplehearth.notification.service;

import com.meeplehearth.common.event.UserHardDeletedEvent;
import com.meeplehearth.common.event.UserSoftDeletedEvent;
import com.meeplehearth.notification.repository.NotificationPreferenceRepository;
import com.meeplehearth.notification.repository.NotificationRepository;
import com.meeplehearth.notification.repository.NotificationSettingsRepository;
import com.meeplehearth.notification.repository.UserFcmTokenRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

/**
 * Account deletion (FEATURES_COMPLETE section 1.6). After the deleting transaction commits:
 * <ul>
 *   <li>soft delete: the user's notifications and device tokens are removed immediately (no more
 *       pushes to the deleted account's devices) and the unread counter is evicted;</li>
 *   <li>hard delete: additionally the notifications the user triggered for others (the unread
 *       counters of their recipients are evicted after commit, so badges are recounted), and the
 *       user's preferences and settings (the {@code users} row cascade would remove the latter
 *       too).</li>
 * </ul>
 */
@Component
public class NotificationAccountListener {

    private static final Logger log = LoggerFactory.getLogger(NotificationAccountListener.class);

    private final NotificationRepository notificationRepository;
    private final UserFcmTokenRepository tokenRepository;
    private final NotificationPreferenceRepository preferenceRepository;
    private final NotificationSettingsRepository settingsRepository;
    private final UnreadCounter unreadCounter;

    public NotificationAccountListener(NotificationRepository notificationRepository,
                                       UserFcmTokenRepository tokenRepository,
                                       NotificationPreferenceRepository preferenceRepository,
                                       NotificationSettingsRepository settingsRepository,
                                       UnreadCounter unreadCounter) {
        this.notificationRepository = notificationRepository;
        this.tokenRepository = tokenRepository;
        this.preferenceRepository = preferenceRepository;
        this.settingsRepository = settingsRepository;
        this.unreadCounter = unreadCounter;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void onSoftDeleted(UserSoftDeletedEvent event) {
        UUID userId = event.userId();
        int notifications = notificationRepository.deleteAllForRecipient(userId);
        int tokens = tokenRepository.deleteAllForUser(userId);
        unreadCounter.evict(userId);
        log.info("Account {} soft-deleted: removed {} notification(s) and {} device token(s)",
                userId, notifications, tokens);
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void onHardDeleted(UserHardDeletedEvent event) {
        UUID userId = event.userId();
        int received = notificationRepository.deleteAllForRecipient(userId);
        // Their badges counted the unread ones: recount once this transaction commits
        List<UUID> affected = notificationRepository.findUnreadRecipientsByActor(userId);
        int triggered = notificationRepository.deleteAllByActor(userId);
        evictAfterCommit(affected);
        tokenRepository.deleteAllForUser(userId);
        preferenceRepository.deleteAllForUser(userId);
        settingsRepository.deleteById(userId);
        unreadCounter.evict(userId);
        log.info("Account {} hard-deleted: removed {} received and {} triggered notification(s)",
                userId, received, triggered);
    }

    private void evictAfterCommit(Collection<UUID> recipients) {
        if (recipients.isEmpty()) {
            return;
        }
        Runnable evict = () -> recipients.forEach(unreadCounter::evict);
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    evict.run();
                }
            });
        } else {
            evict.run();
        }
    }
}
