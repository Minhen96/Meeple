package com.meeplehearth.user.service;

import com.meeplehearth.auth.dto.MessageResponse;
import com.meeplehearth.auth.util.TokenHashing;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.common.ratelimit.RedisRateLimiter;
import com.meeplehearth.user.dto.ChangeEmailRequest;
import com.meeplehearth.user.entity.EmailChangeToken;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.EmailChangeTokenRepository;
import com.meeplehearth.user.repository.UserRepository;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.Locale;
import java.util.UUID;

/**
 * Change of the account email (FEATURES_COMPLETE section 1.7): the current password confirms the
 * request, a link is emailed to the new address and the old address is notified. The email
 * changes only when the link is opened.
 */
@Service
public class EmailChangeService {

    static final Duration TOKEN_EXPIRY = Duration.ofHours(24);
    static final long REQUESTS_PER_HOUR = 3L;
    private static final int TOKEN_BYTES = 32;

    private final UserRepository userRepository;
    private final EmailChangeTokenRepository tokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final RedisRateLimiter rateLimiter;
    private final AccountMailer mailer;

    public EmailChangeService(UserRepository userRepository,
                              EmailChangeTokenRepository tokenRepository,
                              PasswordEncoder passwordEncoder,
                              RedisRateLimiter rateLimiter,
                              AccountMailer mailer) {
        this.userRepository = userRepository;
        this.tokenRepository = tokenRepository;
        this.passwordEncoder = passwordEncoder;
        this.rateLimiter = rateLimiter;
        this.mailer = mailer;
    }

    @Transactional
    public MessageResponse requestChange(UUID userId, ChangeEmailRequest req) {
        User user = userRepository.findById(userId)
                .filter(u -> u.getDeletedAt() == null)
                .orElseThrow(() -> ApiException.notFound("USER_NOT_FOUND", "User not found"));

        if (user.getPasswordHash() == null) {
            throw ApiException.badRequest("PASSWORD_REQUIRED",
                    "This account signs in with Google and has no password to confirm the change");
        }
        if (!passwordEncoder.matches(req.currentPassword(), user.getPasswordHash())) {
            throw ApiException.badRequest("INVALID_PASSWORD", "Current password is incorrect");
        }

        String newEmail = req.newEmail().trim().toLowerCase(Locale.ROOT);
        if (newEmail.equalsIgnoreCase(user.getEmail())) {
            throw ApiException.badRequest("EMAIL_UNCHANGED", "That is already your email address");
        }
        if (userRepository.existsByEmailIgnoreCase(newEmail)) {
            throw ApiException.conflict("EMAIL_TAKEN", "Email address is already in use");
        }
        if (!rateLimiter.tryAcquire("account:change-email:" + userId, REQUESTS_PER_HOUR, Duration.ofHours(1))) {
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "RATE_LIMIT_EXCEEDED",
                    "Too many email change requests. Try again later.");
        }

        tokenRepository.deletePendingByUserId(userId);
        String rawToken = TokenHashing.randomHex(TOKEN_BYTES);
        EmailChangeToken token = new EmailChangeToken();
        token.setUserId(userId);
        token.setNewEmail(newEmail);
        token.setTokenHash(TokenHashing.sha256Hex(rawToken));
        token.setExpiresAt(Instant.now().plus(TOKEN_EXPIRY));
        tokenRepository.save(token);

        mailer.sendEmailChangeVerification(userId, newEmail, rawToken, user.getPreferredLanguage(), TOKEN_EXPIRY);
        mailer.sendEmailChangeNotice(userId, user.getEmail(), user.getPreferredLanguage());
        return new MessageResponse("Check your new email address for a confirmation link.");
    }

    @Transactional
    public MessageResponse confirm(String rawToken) {
        if (rawToken == null || rawToken.isBlank()) {
            throw ApiException.badRequest("MISSING_TOKEN", "Confirmation token is required");
        }
        EmailChangeToken token = tokenRepository.findByTokenHash(TokenHashing.sha256Hex(rawToken.trim()))
                .orElseThrow(() -> ApiException.badRequest("INVALID_TOKEN", "Confirmation link is invalid"));
        if (token.getUsedAt() != null) {
            throw ApiException.badRequest("TOKEN_USED", "This confirmation link has already been used");
        }
        if (Instant.now().isAfter(token.getExpiresAt())) {
            throw ApiException.badRequest("TOKEN_EXPIRED", "This confirmation link has expired");
        }
        User user = userRepository.findById(token.getUserId())
                .filter(u -> u.getDeletedAt() == null)
                .orElseThrow(() -> ApiException.badRequest("INVALID_TOKEN", "Confirmation link is invalid"));

        userRepository.findByEmailIgnoreCase(token.getNewEmail())
                .filter(other -> !other.getId().equals(user.getId()))
                .ifPresent(other -> {
                    throw ApiException.conflict("EMAIL_TAKEN", "Email address is already in use");
                });

        user.setEmail(token.getNewEmail());
        user.setEmailVerified(true);
        token.setUsedAt(Instant.now());
        tokenRepository.save(token);
        try {
            userRepository.saveAndFlush(user);
        } catch (DataIntegrityViolationException e) {
            throw ApiException.conflict("EMAIL_TAKEN", "Email address is already in use");
        }
        return new MessageResponse("Your email address has been updated.");
    }
}
