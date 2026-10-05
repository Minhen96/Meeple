package com.meeplehearth.social.service;

import com.meeplehearth.common.event.UserSoftDeletedEvent;
import com.meeplehearth.social.repository.FriendRequestRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Social-graph cleanup when an account is soft-deleted: pending friend requests sent or received
 * by the user are removed. Accepted friendships are kept so a reactivation within the 30-day grace
 * period restores them; feeds, search and suggestions already hide soft-deleted users.
 */
@Component
public class SocialAccountListener {

    private static final Logger log = LoggerFactory.getLogger(SocialAccountListener.class);

    private final FriendRequestRepository friendRequestRepository;

    public SocialAccountListener(FriendRequestRepository friendRequestRepository) {
        this.friendRequestRepository = friendRequestRepository;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void onUserSoftDeleted(UserSoftDeletedEvent event) {
        int removed = friendRequestRepository.deletePendingInvolving(event.userId());
        log.info("Removed {} pending friend requests of soft-deleted user {}", removed, event.userId());
    }
}
