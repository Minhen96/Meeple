package com.meeplehearth.post.service;

import com.meeplehearth.common.event.UserHardDeletedEvent;
import com.meeplehearth.common.event.UserSoftDeletedEvent;
import com.meeplehearth.post.repository.PostQueryRepository;
import com.meeplehearth.storage.service.ObjectStorageService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.util.List;
import java.util.Optional;

/**
 * Post data cleanup on account deletion (docs/GAP_ANALYSIS.md section 6.2):
 * <ul>
 *   <li>soft delete: the user's bookmarks are removed (their posts are already hidden everywhere
 *       because every query filters on the author's {@code deleted_at});</li>
 *   <li>hard delete: the user's posts are permanently deleted, with their images, tags, likes,
 *       comments and other users' bookmarks of them (FK cascades), and the posts' images are
 *       removed from R2 (they live under {@code posts/{postId}/} once moved, outside the user's
 *       upload folder that the hard-delete job clears). The user's comments on other people's
 *       posts are kept and show "Deleted User" (V60).</li>
 * </ul>
 */
@Component
public class PostAccountListener {

    private static final Logger log = LoggerFactory.getLogger(PostAccountListener.class);

    private final PostQueryRepository postQueryRepository;
    private final ObjectStorageService storage;

    public PostAccountListener(PostQueryRepository postQueryRepository, ObjectStorageService storage) {
        this.postQueryRepository = postQueryRepository;
        this.storage = storage;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void onUserSoftDeleted(UserSoftDeletedEvent event) {
        int removed = postQueryRepository.deleteBookmarksOfUser(event.userId());
        log.info("Removed {} bookmarks of soft-deleted user {}", removed, event.userId());
    }

    /**
     * Runs inside the hard-delete transaction, while the user's posts still exist (deleting the
     * user row cascades to them): collects their image keys, and deletes those objects once the
     * transaction commits. Images another author's post also uses are kept.
     */
    @EventListener
    public void collectImagesOnUserHardDeleted(UserHardDeletedEvent event) {
        List<String> keys = postQueryRepository.imageUrlsOnlyUsedBy(event.userId()).stream()
                .map(storage::keyFromPublicUrl)
                .flatMap(Optional::stream)
                .toList();
        if (keys.isEmpty()) {
            return;
        }
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    storage.deleteKeysQuietly(keys);
                }
            });
        } else {
            storage.deleteKeysQuietly(keys);
        }
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void onUserHardDeleted(UserHardDeletedEvent event) {
        int removed = postQueryRepository.hardDeletePostsOf(event.userId());
        log.info("Hard-deleted {} posts of user {}", removed, event.userId());
    }
}
