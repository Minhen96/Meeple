package com.meeplehearth.user.service;

import com.meeplehearth.auth.repository.RefreshTokenRepository;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.user.dto.UpdateProfileRequest;
import com.meeplehearth.user.dto.UserProfileResponse;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.UUID;

@Service
public class UserService {

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;

    public UserService(UserRepository userRepository,
                       RefreshTokenRepository refreshTokenRepository) {
        this.userRepository = userRepository;
        this.refreshTokenRepository = refreshTokenRepository;
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

        if (req.displayName() != null) user.setDisplayName(req.displayName());
        if (req.bio() != null)         user.setBio(req.bio());
        if (req.location() != null)    user.setLocation(req.location());
        if (req.avatarUrl() != null)   user.setAvatarUrl(req.avatarUrl());

        return UserProfileResponse.from(userRepository.save(user));
    }

    @Transactional
    public void deleteMe(UUID userId) {
        User user = findActiveUser(userId);
        user.setDeletedAt(Instant.now());
        userRepository.save(user);
        // Revoke all sessions
        refreshTokenRepository.deleteByUserId(userId);
    }

    private User findActiveUser(UUID userId) {
        return userRepository.findById(userId)
                .filter(u -> u.getDeletedAt() == null)
                .orElseThrow(() -> ApiException.notFound("USER_NOT_FOUND", "User not found"));
    }
}
