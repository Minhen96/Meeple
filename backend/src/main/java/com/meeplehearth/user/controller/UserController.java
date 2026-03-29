package com.meeplehearth.user.controller;

import com.meeplehearth.common.dto.PageResponse;
import com.meeplehearth.user.dto.UpdateProfileRequest;
import com.meeplehearth.user.dto.UserProfileResponse;
import com.meeplehearth.user.service.UserService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/users")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    /** GET /api/v1/users/me — current user's full profile */
    @GetMapping("/me")
    public ResponseEntity<UserProfileResponse> getMe(
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(userService.getMe(userId));
    }

    /** PUT /api/v1/users/me — update display name, bio, location, avatarUrl */
    @PutMapping("/me")
    public ResponseEntity<UserProfileResponse> updateMe(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody UpdateProfileRequest request) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(userService.updateMe(userId, request));
    }

    /** DELETE /api/v1/users/me — soft-delete account, revoke all sessions */
    @DeleteMapping("/me")
    public ResponseEntity<Void> deleteMe(
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        userService.deleteMe(userId);
        return ResponseEntity.noContent().build();
    }

    /** GET /api/v1/users/search?q= — search by username or display name */
    @GetMapping("/search")
    public ResponseEntity<PageResponse<UserProfileResponse>> search(
            @RequestParam String q,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(userService.search(q, page, size));
    }

    /** GET /api/v1/users/suggestions — people you may know */
    @GetMapping("/suggestions")
    public ResponseEntity<PageResponse<UserProfileResponse>> getSuggestions(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(userService.getSuggestions(userId, page, size));
    }

    /** GET /api/v1/users/{id} — public profile of any user */
    @GetMapping("/{id}")
    public ResponseEntity<UserProfileResponse> getUser(@PathVariable UUID id) {
        return ResponseEntity.ok(userService.getUser(id));
    }
}
