package com.meeplehearth.user.service;

import com.meeplehearth.auth.repository.RefreshTokenRepository;
import com.meeplehearth.common.dto.PageResponse;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.social.repository.FriendRequestRepository;
import com.meeplehearth.user.dto.UpdateProfileRequest;
import com.meeplehearth.user.dto.UserProfileResponse;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
public class UserService {

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final FriendRequestRepository friendRequestRepository;

    public UserService(UserRepository userRepository,
                       RefreshTokenRepository refreshTokenRepository,
                       FriendRequestRepository friendRequestRepository) {
        this.userRepository = userRepository;
        this.refreshTokenRepository = refreshTokenRepository;
        this.friendRequestRepository = friendRequestRepository;
    }

    public UserProfileResponse getMe(UUID userId) {
        return UserProfileResponse.from(findActiveUser(userId));
    }

    public UserProfileResponse getUser(UUID userId) {
        User user = userRepository.findById(userId)
                .filter(u -> u.getDeletedAt() == null)
                .orElseThrow(() -> ApiException.notFound("USER_NOT_FOUND", "User not found"));
        return UserProfileResponse.from(user);
    }

    @Transactional
    public UserProfileResponse updateMe(UUID userId, UpdateProfileRequest req) {
        User user = findActiveUser(userId);

        if (req.displayName() != null)          user.setDisplayName(req.displayName());
        if (req.bio() != null)                  user.setBio(req.bio());
        if (req.location() != null)             user.setLocation(req.location());
        if (req.avatarUrl() != null)            user.setAvatarUrl(req.avatarUrl());
        if (Boolean.TRUE.equals(req.onboardingCompleted())) user.setOnboardingCompleted(true);

        return UserProfileResponse.from(userRepository.save(user));
    }

    @Transactional
    public void deleteMe(UUID userId) {
        User user = findActiveUser(userId);
        user.setDeletedAt(Instant.now());
        userRepository.save(user);
        refreshTokenRepository.deleteByUserId(userId);
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

    private User findActiveUser(UUID userId) {
        return userRepository.findById(userId)
                .filter(u -> u.getDeletedAt() == null)
                .orElseThrow(() -> ApiException.notFound("USER_NOT_FOUND", "User not found"));
    }
}
