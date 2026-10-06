package com.meeplehearth.game.service;

import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.game.dto.UserGameResponse;
import com.meeplehearth.social.repository.BlockRepository;
import com.meeplehearth.social.repository.FriendRequestRepository;
import com.meeplehearth.user.repository.UserRepository;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.UUID;

/**
 * Who may see another user's library data (collection, plays, stats). Profiles are public to
 * signed-in users in the MVP (FEATURES_COMPLETE section 9.3), except that a block in either
 * direction, or a deleted account, makes the user look nonexistent (404, never 403, so a blocked
 * viewer cannot tell they were blocked).
 */
@Component
public class LibraryAccessGuard {

    private final UserRepository userRepository;
    private final BlockRepository blockRepository;
    private final FriendRequestRepository friendRequestRepository;

    public LibraryAccessGuard(UserRepository userRepository, BlockRepository blockRepository,
                              FriendRequestRepository friendRequestRepository) {
        this.userRepository = userRepository;
        this.blockRepository = blockRepository;
        this.friendRequestRepository = friendRequestRepository;
    }

    /**
     * {@code ownerId}'s collection entries as {@code viewerId} may see them: the owner gets
     * everything; anyone else never gets the private notes, and gets the personal rating only as
     * an accepted friend (ratings feed the "friend average rating", FEATURES_COMPLETE section 3.3).
     */
    public List<UserGameResponse> collectionFor(UUID viewerId, UUID ownerId, List<UserGameResponse> entries) {
        if (ownerId.equals(viewerId)) {
            return entries;
        }
        boolean friend = friendRequestRepository.areFriends(viewerId, ownerId);
        return entries.stream().map(entry -> entry.forOtherViewer(friend)).toList();
    }

    /** @throws ApiException 404 USER_NOT_FOUND unless {@code viewerId} may see {@code targetId}'s library */
    public void requireVisible(UUID viewerId, UUID targetId) {
        boolean visible = userRepository.findById(targetId)
                .filter(u -> u.getDeletedAt() == null)
                .isPresent();
        if (!visible || (!targetId.equals(viewerId) && blockRepository.existsBlockBetween(viewerId, targetId))) {
            throw ApiException.notFound("USER_NOT_FOUND", "User not found");
        }
    }
}
