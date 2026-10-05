package com.meeplehearth.ai.service;

import com.meeplehearth.notification.service.NotificationService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Notifies rulebook uploaders about review decisions once the review transaction has committed
 * (nothing is sent for a rolled-back review). The reference is the game, so the notification
 * opens the game page. Failures are logged; the review itself already succeeded.
 */
@Component
public class RulebookNotificationListener {

    private static final Logger log = LoggerFactory.getLogger(RulebookNotificationListener.class);
    static final String REFERENCE_TYPE = "GAME";

    private final NotificationService notificationService;
    /** After commit the old transaction's resources are still bound: writes need a new transaction. */
    private final TransactionTemplate requiresNew;

    public RulebookNotificationListener(NotificationService notificationService,
                                        PlatformTransactionManager transactionManager) {
        this.notificationService = notificationService;
        this.requiresNew = new TransactionTemplate(transactionManager);
        this.requiresNew.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onRulebookReviewed(RulebookReviewedEvent event) {
        if (event.uploaderId() == null || event.uploaderId().equals(event.reviewerId())) {
            return;
        }
        try {
            requiresNew.executeWithoutResult(status -> notificationService.send(event.uploaderId(), event.type(),
                    event.reviewerId(), event.gameId(), REFERENCE_TYPE));
        } catch (RuntimeException e) {
            log.warn("Could not send {} to user {}", event.type(), event.uploaderId(), e);
        }
    }
}
