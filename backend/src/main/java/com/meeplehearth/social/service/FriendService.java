package com.meeplehearth.social.service;

import com.meeplehearth.common.dto.PageResponse;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.feed.service.FeedCache;
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
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
public class FriendService {

    private final FriendRequestRepository friendRequestRepository;
    private final BlockRepository blockRepository;
    private final UserRepository userRepository;
    private final NotificationService notificationService;
    private final StringRedisTemplate redis;
    private final FeedCache feedCache;

    /** After a decline the sender must wait this long before asking the same person again. */
    static final Duration DECLINE_COOLDOWN = Duration.ofDays(7);
    /** Maximum outgoing requests a user may have pending at once (spam guard). */
    static final int MAX_PENDING_OUTGOING = 50;

    public FriendService(FriendRequestRepository friendRequestRepository,
                         BlockRepository blockRepository,
                         UserRepository userRepository,
                         NotificationService notificationService,
                         StringRedisTemplate redis,
                         FeedCache feedCache) {
        this.friendRequestRepository = friendRequestRepository;
        this.blockRepository = blockRepository;
        this.userRepository = userRepository;
        this.notificationService = notificationService;
        this.redis = redis;
        this.feedCache = feedCache;
    }

    static String cooldownKey(UUID senderId, UUID receiverId) {
        return "fr:cooldown:" + senderId + ":" + receiverId;
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
        if (blockRepository.existsBlockBetween(senderId, receiverId)) {
            throw ApiException.forbidden("BLOCKED", "Cannot send friend request");
        }

        // Check for existing request in either direction
        List<FriendRequest> existing = friendRequestRepository.findBetween(senderId, receiverId);
        if (existing.stream().anyMatch(r -> r.getStatus() == FriendRequest.Status.ACCEPTED)) {
            throw ApiException.conflict("ALREADY_FRIENDS", "Already friends");
        }
        Optional<FriendRequest> pending = existing.stream()
                .filter(r -> r.getStatus() == FriendRequest.Status.PENDING)
                .findFirst();
        if (pending.isPresent()) {
            FriendRequest fr = pending.get();
            if (fr.getSender().getId().equals(senderId)) {
                throw ApiException.conflict("REQUEST_PENDING", "Friend request already pending");
            }
            // The other person already asked us: mutual intent, so accept their request.
            return acceptFriendRequest(senderId, fr.getId());
        }

        if (Boolean.TRUE.equals(redis.hasKey(cooldownKey(senderId, receiverId)))) {
            throw ApiException.conflict("REQUEST_COOLDOWN",
                    "You can send another request to this user 7 days after it was declined");
        }
        if (friendRequestRepository.countBySenderIdAndStatus(senderId, FriendRequest.Status.PENDING)
                >= MAX_PENDING_OUTGOING) {
            throw ApiException.conflict("PENDING_LIMIT",
                    "You have too many pending friend requests; wait for some to be answered");
        }

        if (!existing.isEmpty()) {
            // DECLINED — allow re-send by reusing an existing record. Prefer a row already
            // sent by the current user; otherwise flip the declined row so the current user
            // becomes the sender (the unique key is (sender_id, receiver_id)).
            FriendRequest fr = existing.stream()
                    .filter(r -> r.getSender().getId().equals(senderId))
                    .findFirst()
                    .orElse(existing.get(0));
            if (!fr.getSender().getId().equals(senderId)) {
                fr.setSender(findActiveUser(senderId));
                fr.setReceiver(receiver);
            }
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
        feedCache.invalidateAfterCommit(fr.getSender().getId(), currentUserId);

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

    /** Withdraws the pending request the current user sent to {@code targetUserId}. */
    @Transactional
    public void cancelFriendRequestTo(UUID currentUserId, UUID targetUserId) {
        FriendRequest fr = friendRequestRepository.findBySenderIdAndReceiverId(currentUserId, targetUserId)
                .filter(r -> r.getStatus() == FriendRequest.Status.PENDING)
                .orElseThrow(() -> ApiException.notFound("REQUEST_NOT_FOUND", "No pending friend request to this user"));
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
        FriendRequestResponse response = FriendRequestResponse.from(friendRequestRepository.save(fr));
        // Silent for the sender (no notification), but they must wait before asking again
        redis.opsForValue().set(cooldownKey(fr.getSender().getId(), currentUserId), "1", DECLINE_COOLDOWN);
        return response;
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
                        fr -> {
                            friendRequestRepository.delete(fr);
                            feedCache.invalidateAfterCommit(currentUserId, targetUserId);
                        },
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
        if (!userRepository.existsById(blockedId)) {
            throw ApiException.notFound("USER_NOT_FOUND", "User not found");
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
        feedCache.invalidateAfterCommit(blockerId, blockedId);
    }

    @Transactional
    public void unblockUser(UUID blockerId, UUID blockedId) {
        blockRepository.deleteById(new BlockedUserId(blockerId, blockedId));
        feedCache.invalidateAfterCommit(blockerId, blockedId);
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
