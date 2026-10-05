package com.meeplehearth.auth.service;

import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
public class UserDetailsServiceImpl implements UserDetailsService {

    private final UserRepository userRepository;

    public UserDetailsServiceImpl(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    /**
     * Loads a user by their UUID (the "username" in our JWT-based system is the user's UUID string).
     * Throws UsernameNotFoundException if the user does not exist or has been soft-deleted.
     */
    @Override
    public UserDetails loadUserByUsername(String userId) throws UsernameNotFoundException {
        UUID id;
        try {
            id = UUID.fromString(userId);
        } catch (IllegalArgumentException e) {
            throw new UsernameNotFoundException("Invalid user ID format: " + userId);
        }

        return toUserDetails(findActiveUser(id));
    }

    /**
     * Loads the user an access token belongs to, rejecting tokens whose embedded token version
     * is older than the user's current one (revoked by password reset or session revocation).
     * The user row is already read on every authenticated request, so this check adds no query.
     */
    public UserDetails loadUserForAccessToken(UUID userId, int tokenVersion) {
        User user = findActiveUser(userId);
        if (user.getTokenVersion() != tokenVersion) {
            throw new UsernameNotFoundException("Access token has been revoked");
        }
        return toUserDetails(user);
    }

    private User findActiveUser(UUID id) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> new UsernameNotFoundException("User not found: " + id));

        if (user.getDeletedAt() != null) {
            throw new UsernameNotFoundException("User account has been deleted: " + id);
        }
        return user;
    }

    private UserDetails toUserDetails(User user) {
        return org.springframework.security.core.userdetails.User.builder()
                .username(user.getId().toString())
                .password(user.getPasswordHash() != null ? user.getPasswordHash() : "")
                .authorities("ROLE_" + user.getRole())
                .build();
    }
}
