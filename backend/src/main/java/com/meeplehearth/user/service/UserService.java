package com.meeplehearth.user.service;

import com.meeplehearth.auth.event.UserSessionsRevokedEvent;
import com.meeplehearth.auth.repository.RefreshTokenRepository;
import com.meeplehearth.common.dto.PageResponse;
import com.meeplehearth.common.event.UserSoftDeletedEvent;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.social.repository.BlockRepository;
import com.meeplehearth.social.repository.FriendRequestRepository;
import com.meeplehearth.user.AccountPolicy;
import com.meeplehearth.user.dto.UpdateProfileRequest;
import com.meeplehearth.user.dto.UserProfileResponse;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.DateTimeException;
import java.time.Instant;
import java.time.ZoneId;
import java.util.List;
import java.util.UUID;

@Service
public class UserService {

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final FriendRequestRepository friendRequestRepository;
    private final ApplicationEventPublisher eventPublisher;
    private final BlockRepository blockRepository;

    public UserService(UserRepository userRepository,
                       RefreshTokenRepository refreshTokenRepository,
                       FriendRequestRepository friendRequestRepository,
                       ApplicationEventPublisher eventPublisher,
                       BlockRepository blockRepository) {
        this.userRepository = userRepository;
        this.refreshTokenRepository = refreshTokenRepository;
        this.friendRequestRepository = friendRequestRepository;
        this.eventPublisher = eventPublisher;
        this.blockRepository = blockRepository;
    }

    public UserProfileResponse getMe(UUID userId) {
        return UserProfileResponse.self(findActiveUser(userId));
    }

    /**
     * A user's public profile. 404 when the user is deleted or when either user has blocked the
     * other (FEATURES_COMPLETE sections 2.2, 9.3), so a block cannot be detected from outside.
     */
    public UserProfileResponse getUser(UUID viewerId, UUID userId) {
        if (viewerId != null && viewerId.equals(userId)) {
            return getMe(userId);
        }
        User user = userRepository.findById(userId)
                .filter(u -> u.getDeletedAt() == null)
                .orElseThrow(() -> ApiException.notFound("USER_NOT_FOUND", "User not found"));
        if (viewerId != null && blockRepository.existsBlockBetween(viewerId, userId)) {
            throw ApiException.notFound("USER_NOT_FOUND", "User not found");
        }
        return UserProfileResponse.from(user);
    }

    @Transactional
    public UserProfileResponse updateMe(UUID userId, UpdateProfileRequest req) {
        User user = findActiveUser(userId);

        if (req.displayName() != null) {
            String displayName = req.displayName().strip();
            if (displayName.isEmpty()) {
                throw ApiException.badRequest("VALIDATION_ERROR", "displayName: must not be blank");
            }
            user.setDisplayName(displayName);
        }
        if (req.bio() != null)                  user.setBio(req.bio().strip());
        if (req.location() != null)             user.setLocation(req.location().strip());
        if (req.avatarUrl() != null)            user.setAvatarUrl(req.avatarUrl());
        if (Boolean.TRUE.equals(req.onboardingCompleted())) user.setOnboardingCompleted(true);
        if (req.preferredLanguage() != null)    user.setPreferredLanguage(req.preferredLanguage());
        if (req.timezone() != null)             user.setTimezone(validTimezone(req.timezone()));
        if (req.username() != null && !req.username().equals(user.getUsername())) {
            changeUsername(user, req.username());
        }

        try {
            return UserProfileResponse.self(userRepository.saveAndFlush(user));
        } catch (DataIntegrityViolationException e) {
            // Lost a race for the same username against another account
            throw ApiException.conflict("USERNAME_TAKEN", "Username is already taken");
        }
    }

    private void changeUsername(User user, String username) {
        Instant now = Instant.now();
        Instant availableAt = AccountPolicy.usernameChangeAvailableAt(user.getUsernameChangedAt(), now);
        if (availableAt != null) {
            throw ApiException.badRequest("USERNAME_CHANGE_TOO_SOON",
                    "You can change your username again after " + availableAt);
        }
        if (userRepository.existsByUsernameIgnoreCase(username)) {
            throw ApiException.conflict("USERNAME_TAKEN", "Username is already taken");
        }
        user.setUsername(username);
        user.setUsernameChangedAt(now);
    }

    private static String validTimezone(String timezone) {
        String trimmed = timezone.strip();
        if (trimmed.isEmpty()) {
            return null;
        }
        try {
            return ZoneId.of(trimmed).getId();
        } catch (DateTimeException e) {
            throw ApiException.badRequest("INVALID_TIMEZONE", "timezone: must be an IANA time zone");
        }
    }

    /**
     * Soft-deletes the account: sets deleted_at, ends every session (refresh tokens deleted,
     * token version bumped so outstanding access tokens die with them) and publishes
     * {@link UserSoftDeletedEvent} so each package removes its own data after commit.
     * Credentials are checked by {@link AccountDeletionService} before this is called.
     */
    @Transactional
    public void deleteMe(UUID userId) {
        User user = findActiveUser(userId);
        user.setDeletedAt(Instant.now());
        user.setTokenVersion(user.getTokenVersion() + 1);
        userRepository.save(user);
        refreshTokenRepository.deleteByUserId(userId);
        // Closes the user's open WebSocket sessions once the soft-delete commits
        eventPublisher.publishEvent(new UserSessionsRevokedEvent(userId));
        // Each package cleans up its own data after the soft-delete commits
        eventPublisher.publishEvent(new UserSoftDeletedEvent(userId));
    }

    public PageResponse<UserProfileResponse> search(String q, int page, int size) {
        return PageResponse.of(
                userRepository.searchByUsernameOrDisplayName(q.trim(), PageRequest.of(page, size)),
                UserProfileResponse::from
        );
    }

    public PageResponse<UserProfileResponse> getSuggestions(UUID currentUserId, int page, int size) {
        List<UUID> friendIds = friendRequestRepository.findFriendIds(currentUserId);
        // Exclude self + existing friends
        List<UUID> excludeIds = new java.util.ArrayList<>(friendIds);
        excludeIds.add(currentUserId);
        return PageResponse.of(
                userRepository.findSuggestions(currentUserId, excludeIds, PageRequest.of(page, size)),
                UserProfileResponse::from
        );
    }

    @Transactional
    public void promoteToAdmin(UUID userId) {
        User user = findActiveUser(userId);
        if ("ADMIN".equals(user.getRole())) {
            throw ApiException.badRequest("ALREADY_ADMIN", "User is already an admin");
        }
        user.setRole("ADMIN");
        userRepository.save(user);
    }

    User findActiveUser(UUID userId) {
        return userRepository.findById(userId)
                .filter(u -> u.getDeletedAt() == null)
                .orElseThrow(() -> ApiException.notFound("USER_NOT_FOUND", "User not found"));
    }
}
