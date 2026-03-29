package com.meeplehearth.social.controller;

import com.meeplehearth.common.dto.PageResponse;
import com.meeplehearth.social.dto.FriendRequestResponse;
import com.meeplehearth.social.dto.FriendStatusResponse;
import com.meeplehearth.social.service.FriendService;
import com.meeplehearth.user.dto.UserProfileResponse;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
public class FriendController {

    private final FriendService friendService;

    public FriendController(FriendService friendService) {
        this.friendService = friendService;
    }

    /** POST /api/v1/users/{id}/friend-request — send a friend request */
    @PostMapping("/api/v1/users/{id}/friend-request")
    public ResponseEntity<FriendRequestResponse> sendFriendRequest(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id) {
        UUID currentUserId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(friendService.sendFriendRequest(currentUserId, id));
    }

    /** GET /api/v1/users/{id}/friend-status — current user's relationship with target user */
    @GetMapping("/api/v1/users/{id}/friend-status")
    public ResponseEntity<FriendStatusResponse> getFriendStatus(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id) {
        UUID currentUserId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(friendService.getFriendStatus(currentUserId, id));
    }

    /** POST /api/v1/users/{id}/block — block a user */
    @PostMapping("/api/v1/users/{id}/block")
    public ResponseEntity<Void> blockUser(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id) {
        UUID currentUserId = UUID.fromString(userDetails.getUsername());
        friendService.blockUser(currentUserId, id);
        return ResponseEntity.noContent().build();
    }

    /** DELETE /api/v1/users/{id}/block — unblock a user */
    @DeleteMapping("/api/v1/users/{id}/block")
    public ResponseEntity<Void> unblockUser(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id) {
        UUID currentUserId = UUID.fromString(userDetails.getUsername());
        friendService.unblockUser(currentUserId, id);
        return ResponseEntity.noContent().build();
    }

    /** POST /api/v1/friend-requests/{id}/accept — accept a pending request */
    @PostMapping("/api/v1/friend-requests/{id}/accept")
    public ResponseEntity<FriendRequestResponse> acceptFriendRequest(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id) {
        UUID currentUserId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(friendService.acceptFriendRequest(currentUserId, id));
    }

    /** POST /api/v1/friend-requests/{id}/decline — decline a pending request */
    @PostMapping("/api/v1/friend-requests/{id}/decline")
    public ResponseEntity<FriendRequestResponse> declineFriendRequest(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id) {
        UUID currentUserId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(friendService.declineFriendRequest(currentUserId, id));
    }

    /** GET /api/v1/friend-requests/received — pending requests I've received */
    @GetMapping("/api/v1/friend-requests/received")
    public ResponseEntity<PageResponse<FriendRequestResponse>> getReceivedRequests(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        UUID currentUserId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(friendService.getReceivedRequests(currentUserId, page, size));
    }

    /** GET /api/v1/friend-requests/sent — pending requests I've sent */
    @GetMapping("/api/v1/friend-requests/sent")
    public ResponseEntity<PageResponse<FriendRequestResponse>> getSentRequests(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        UUID currentUserId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(friendService.getSentRequests(currentUserId, page, size));
    }

    /** GET /api/v1/friends — my friends list */
    @GetMapping("/api/v1/friends")
    public ResponseEntity<PageResponse<UserProfileResponse>> getFriends(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        UUID currentUserId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(friendService.getFriends(currentUserId, page, size));
    }

    /** DELETE /api/v1/friends/{userId} — unfriend */
    @DeleteMapping("/api/v1/friends/{userId}")
    public ResponseEntity<Void> unfriend(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID userId) {
        UUID currentUserId = UUID.fromString(userDetails.getUsername());
        friendService.unfriend(currentUserId, userId);
        return ResponseEntity.noContent().build();
    }
}
