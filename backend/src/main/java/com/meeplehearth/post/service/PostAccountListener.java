package com.meeplehearth.post.service;

import com.meeplehearth.common.event.UserHardDeletedEvent;
import com.meeplehearth.common.event.UserSoftDeletedEvent;
import com.meeplehearth.post.repository.PostQueryRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Post data cleanup on account deletion (docs/GAP_ANALYSIS.md section 6.2):
 * <ul>
 *   <li>soft delete: the user's bookmarks are removed (their posts are already hidden everywhere
 *       because every query filters on the author's {@code deleted_at});</li>
 *   <li>hard delete: the user's posts are permanently deleted, with their images, tags, likes,
 *       comments and other users' bookmarks of them (FK cascades).</li>
 * </ul>
 */
@Component
public class PostAccountListener {

    private static final Logger log = LoggerFactory.getLogger(PostAccountListener.class);

    private final PostQueryRepository postQueryRepository;

    public PostAccountListener(PostQueryRepository postQueryRepository) {
        this.postQueryRepository = postQueryRepository;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void onUserSoftDeleted(UserSoftDeletedEvent event) {
        int removed = postQueryRepository.deleteBookmarksOfUser(event.userId());
        log.info("Removed {} bookmarks of soft-deleted user {}", removed, event.userId());
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void onUserHardDeleted(UserHardDeletedEvent event) {
        int removed = postQueryRepository.hardDeletePostsOf(event.userId());
        log.info("Hard-deleted {} posts of user {}", removed, event.userId());
    }
}
