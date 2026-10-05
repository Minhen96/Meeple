package com.meeplehearth.user.dto;

import com.meeplehearth.user.AccountPolicy;
import com.meeplehearth.user.entity.User;

import java.time.Instant;
import java.util.UUID;

/**
 * A user's profile. Fields after {@code isVerified} are private: they are filled only when the
 * viewer is the user ({@link #self}) and null for everyone else.
 */
public record UserProfileResponse(
        UUID id,
        String username,
        String displayName,
        String avatarUrl,
        String bio,
        String location,
        boolean onboardingCompleted,
        boolean isAdmin,
        Instant createdAt,
        boolean isVerified,
        String email,
        String preferredLanguage,
        String timezone,
        String bggUsername,
        Instant usernameChangeAvailableAt,
        Boolean hasPassword,
        Boolean googleLinked
) {
    /** Public view of {@code user}, as seen by any other signed-in user. */
    public static UserProfileResponse from(User user) {
        return new UserProfileResponse(
                user.getId(),
                user.getUsername(),
                user.getDisplayName(),
                user.getAvatarUrl(),
                user.getBio(),
                user.getLocation(),
                user.isOnboardingCompleted(),
                "ADMIN".equals(user.getRole()),
                user.getCreatedAt(),
                user.isVerified(),
                null, null, null, null, null, null, null
        );
    }

    /** The user's own view, including account settings. */
    public static UserProfileResponse self(User user) {
        return new UserProfileResponse(
                user.getId(),
                user.getUsername(),
                user.getDisplayName(),
                user.getAvatarUrl(),
                user.getBio(),
                user.getLocation(),
                user.isOnboardingCompleted(),
                "ADMIN".equals(user.getRole()),
                user.getCreatedAt(),
                user.isVerified(),
                user.getEmail(),
                user.getPreferredLanguage(),
                user.getTimezone(),
                user.getBggUsername(),
                AccountPolicy.usernameChangeAvailableAt(user.getUsernameChangedAt(), Instant.now()),
                user.getPasswordHash() != null,
                user.getGoogleId() != null
        );
    }
}
