package com.meeplehearth.social.service;

import com.meeplehearth.common.dto.PageResponse;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.notification.entity.Notification;
import com.meeplehearth.notification.service.NotificationService;
import com.meeplehearth.social.dto.FriendRequestResponse;
import com.meeplehearth.social.dto.FriendStatusResponse;
import com.meeplehearth.social.entity.BlockedUser;
import com.meeplehearth.social.entity.BlockedUserId;
import com.meeplehearth.social.entity.FriendRequest;
import com.meeplehearth.social.repository.BlockRepository;
import com.meeplehearth.social.repository.FriendRequestRepository;
import com.meeplehearth.user.dto.UserProfileResponse;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
public class FriendService {

    private final FriendRequestRepository friendRequestRepository;
    private final BlockRepository blockRepository;
    private final UserRepository userRepository;
    private final NotificationService notificationService;

    public FriendService(FriendRequestRepository friendRequestRepository,
                         BlockRepository blockRepository,
                         UserRepository userRepository,
                         NotificationService notificationService) {
        this.friendRequestRepository = friendRequestRepository;
        this.blockRepository = blockRepository;
        this.userRepository = userRepository;
        this.notificationService = notificationService;
    }

    // -------------------------------------------------------------------------
    // Send friend request
    // -------------------------------------------------------------------------

    @Transactional
    public FriendRequestResponse sendFriendRequest(UUID senderId, UUID receiverId) {
        if (senderId.equals(receiverId)) {
            throw ApiException.badRequest("INVALID_TARGET", "Cannot send friend request to yourself");
        }

        User receiver = findActiveUser(receiverId);

        // Block check — both directions
        if (blockRepository.existsByIdBlockerIdAndIdBlockedId(senderId, receiverId) ||
            blockRepository.existsByIdBlockerIdAndIdBlockedId(receiverId, senderId)) {
            throw ApiException.forbidden("BLOCKED", "Cannot send friend request");
        }

        // Check for existing request in either direction
        List<FriendRequest> existing = friendRequestRepository.findBetween(senderId, receiverId);
        if (!existing.isEmpty()) {
            FriendRequest fr = existing.get(0);
            if (fr.getStatus() == FriendRequest.Status.ACCEPTED) {
                throw ApiException.conflict("ALREADY_FRIENDS", "Already friends");
            }
            if (fr.getStatus() == FriendRequest.Status.PENDING) {
                throw ApiException.conflict("REQUEST_PENDING", "Friend request already pending");
            }
            // DECLINED — allow re-send by updating existing record
            fr.setStatus(FriendRequest.Status.PENDING);
            FriendRequest saved = friendRequestRepository.save(fr);
            notificationService.send(receiverId, Notification.NotificationType.FRIEND_REQUEST, senderId, saved.getId(), "FRIEND_REQUEST");
            return FriendRequestResponse.from(saved);
        }

        User sender = findActiveUser(senderId);
        FriendRequest fr = new FriendRequest();
        fr.setSender(sender);
        fr.setReceiver(receiver);
        FriendRequest saved = friendRequestRepository.save(fr);

        notificationService.send(receiverId, Notification.NotificationType.FRIEND_REQUEST, senderId, saved.getId(), "FRIEND_REQUEST");
        return FriendRequestResponse.from(saved);
    }

    // -------------------------------------------------------------------------
    // Accept
    // -------------------------------------------------------------------------

    @Transactional
    public FriendRequestResponse acceptFriendRequest(UUID currentUserId, UUID requestId) {
        FriendRequest fr = findPendingRequest(requestId);
        if (!fr.getReceiver().getId().equals(currentUserId)) {
            throw ApiException.forbidden("FORBIDDEN", "Not your request to accept");
        }
        fr.setStatus(FriendRequest.Status.ACCEPTED);
        FriendRequest saved = friendRequestRepository.save(fr);

        // Notify sender: "X accepted your friend request"
        notificationService.send(fr.getSender().getId(), Notification.NotificationType.FRIEND_ACCEPTED, currentUserId, saved.getId(), "FRIEND_REQUEST");
        // Notify receiver (self): "You are now friends with X"
        notificationService.send(currentUserId, Notification.NotificationType.FRIEND_ACCEPTED, fr.getSender().getId(), saved.getId(), "FRIEND_REQUEST");
        return FriendRequestResponse.from(saved);
    }

    // -------------------------------------------------------------------------
    // Cancel (sender withdraws their own pending request)
    // -------------------------------------------------------------------------

    @Transactional
    public void cancelFriendRequest(UUID currentUserId, UUID requestId) {
        FriendRequest fr = findPendingRequest(requestId);
        if (!fr.getSender().getId().equals(currentUserId)) {
            throw ApiException.forbidden("FORBIDDEN", "Not your request to cancel");
        }
        friendRequestRepository.delete(fr);
    }

    // -------------------------------------------------------------------------
    // Decline
    // -------------------------------------------------------------------------

    @Transactional
    public FriendRequestResponse declineFriendRequest(UUID currentUserId, UUID requestId) {
        FriendRequest fr = findPendingRequest(requestId);
        if (!fr.getReceiver().getId().equals(currentUserId)) {
            throw ApiException.forbidden("FORBIDDEN", "Not your request to decline");
        }
        fr.setStatus(FriendRequest.Status.DECLINED);
        return FriendRequestResponse.from(friendRequestRepository.save(fr));
    }

    // -------------------------------------------------------------------------
    // Unfriend
    // -------------------------------------------------------------------------

    @Transactional
    public void unfriend(UUID currentUserId, UUID targetUserId) {
        List<FriendRequest> requests = friendRequestRepository.findBetween(currentUserId, targetUserId);
        requests.stream()
                .filter(fr -> fr.getStatus() == FriendRequest.Status.ACCEPTED)
                .findFirst()
                .ifPresentOrElse(
                        fr -> friendRequestRepository.delete(fr),
                        () -> { throw ApiException.notFound("NOT_FRIENDS", "Not friends with this user"); }
                );
    }

    // -------------------------------------------------------------------------
    // Friends list
    // -------------------------------------------------------------------------

    public PageResponse<UserProfileResponse> getFriends(UUID userId, int page, int size) {
        List<UUID> friendIds = friendRequestRepository.findFriendIds(userId);
        if (friendIds.isEmpty()) {
            return PageResponse.empty();
        }
        Page<User> friends = userRepository.findByIdInAndDeletedAtIsNull(friendIds, PageRequest.of(page, size));
        return PageResponse.of(friends, UserProfileResponse::from);
    }

    // -------------------------------------------------------------------------
    // Received pending requests
    // -------------------------------------------------------------------------

    public PageResponse<FriendRequestResponse> getReceivedRequests(UUID userId, int page, int size) {
        Page<FriendRequest> requests = friendRequestRepository.findByReceiverIdAndStatus(
                userId, FriendRequest.Status.PENDING, PageRequest.of(page, size));
        return PageResponse.of(requests, FriendRequestResponse::from);
    }

    // -------------------------------------------------------------------------
    // Sent pending requests
    // -------------------------------------------------------------------------

    public PageResponse<FriendRequestResponse> getSentRequests(UUID userId, int page, int size) {
        Page<FriendRequest> requests = friendRequestRepository.findBySenderIdAndStatus(
                userId, FriendRequest.Status.PENDING, PageRequest.of(page, size));
        return PageResponse.of(requests, FriendRequestResponse::from);
    }

    // -------------------------------------------------------------------------
    // Friend status (for profile view)
    // -------------------------------------------------------------------------

    public FriendStatusResponse getFriendStatus(UUID currentUserId, UUID targetUserId) {
        if (blockRepository.existsByIdBlockerIdAndIdBlockedId(currentUserId, targetUserId)) {
            return FriendStatusResponse.blocked();
        }
        List<FriendRequest> requests = friendRequestRepository.findBetween(currentUserId, targetUserId);
        if (requests.isEmpty()) {
            return FriendStatusResponse.none();
        }
        FriendRequest fr = requests.get(0);
        return switch (fr.getStatus()) {
            case ACCEPTED -> FriendStatusResponse.friends(fr.getId());
            case PENDING -> fr.getSender().getId().equals(currentUserId)
                    ? FriendStatusResponse.pendingSent(fr.getId())
                    : FriendStatusResponse.pendingReceived(fr.getId());
            case DECLINED -> FriendStatusResponse.none();
        };
    }

    // -------------------------------------------------------------------------
    // Block / Unblock
    // -------------------------------------------------------------------------

    @Transactional
    public void blockUser(UUID blockerId, UUID blockedId) {
        if (blockerId.equals(blockedId)) {
            throw ApiException.badRequest("INVALID_TARGET", "Cannot block yourself");
        }
        // Remove any friendship first
        friendRequestRepository.findBetween(blockerId, blockedId)
                .forEach(friendRequestRepository::delete);

        BlockedUserId id = new BlockedUserId(blockerId, blockedId);
        if (!blockRepository.existsById(id)) {
            BlockedUser block = new BlockedUser();
            block.setId(id);
            block.setBlocker(userRepository.getReferenceById(blockerId));
            block.setBlocked(userRepository.getReferenceById(blockedId));
            blockRepository.save(block);
        }
    }

    @Transactional
    public void unblockUser(UUID blockerId, UUID blockedId) {
        blockRepository.deleteById(new BlockedUserId(blockerId, blockedId));
    }

    // -------------------------------------------------------------------------
    // Friend IDs (used by PostService for feed)
    // -------------------------------------------------------------------------

    public List<UUID> getFriendIds(UUID userId) {
        return friendRequestRepository.findFriendIds(userId);
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private FriendRequest findPendingRequest(UUID requestId) {
        FriendRequest fr = friendRequestRepository.findById(requestId)
                .orElseThrow(() -> ApiException.notFound("REQUEST_NOT_FOUND", "Friend request not found"));
        if (fr.getStatus() != FriendRequest.Status.PENDING) {
            throw ApiException.badRequest("REQUEST_NOT_PENDING", "Request is no longer pending");
        }
        return fr;
    }

    private User findActiveUser(UUID userId) {
        return userRepository.findById(userId)
                .filter(u -> u.getDeletedAt() == null)
                .orElseThrow(() -> ApiException.notFound("USER_NOT_FOUND", "User not found"));
    }
}
