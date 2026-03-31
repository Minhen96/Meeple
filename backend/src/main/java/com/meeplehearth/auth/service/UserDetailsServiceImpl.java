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

        User user = userRepository.findById(id)
                .orElseThrow(() -> new UsernameNotFoundException("User not found: " + userId));

        if (user.getDeletedAt() != null) {
            throw new UsernameNotFoundException("User account has been deleted: " + userId);
        }

        return org.springframework.security.core.userdetails.User.builder()
                .username(user.getId().toString())
                .password(user.getPasswordHash() != null ? user.getPasswordHash() : "")
                .authorities("ROLE_" + user.getRole())
                .build();
    }
}
