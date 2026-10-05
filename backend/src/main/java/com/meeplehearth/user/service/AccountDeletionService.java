package com.meeplehearth.user.service;

import com.meeplehearth.auth.service.GoogleAuthService;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.user.AccountPolicy;
import com.meeplehearth.user.dto.DeleteAccountRequest;
import com.meeplehearth.user.entity.User;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.UUID;

/**
 * Account deletion with re-authentication (FEATURES_COMPLETE section 1.6, decision C11):
 * <ul>
 *   <li>accounts with a password must send it;</li>
 *   <li>accounts without one (Google sign-in only) send a Google ID token issued in the last
 *       {@link #GOOGLE_REAUTH_MAX_AGE} for the same Google account, or type {@code "DELETE"}.</li>
 * </ul>
 * Deletion is a soft delete with a 30-day grace period; a confirmation email tells the user how
 * to reactivate.
 */
@Service
public class AccountDeletionService {

    private static final Logger log = LoggerFactory.getLogger(AccountDeletionService.class);
    static final Duration GOOGLE_REAUTH_MAX_AGE = Duration.ofMinutes(10);

    private final UserService userService;
    private final PasswordEncoder passwordEncoder;
    private final GoogleAuthService googleAuthService;
    private final AccountMailer mailer;

    public AccountDeletionService(UserService userService,
                                  PasswordEncoder passwordEncoder,
                                  GoogleAuthService googleAuthService,
                                  AccountMailer mailer) {
        this.userService = userService;
        this.passwordEncoder = passwordEncoder;
        this.googleAuthService = googleAuthService;
        this.mailer = mailer;
    }

    @Transactional
    public void deleteAccount(UUID userId, DeleteAccountRequest req) {
        User user = userService.findActiveUser(userId);
        DeleteAccountRequest body = req == null ? new DeleteAccountRequest(null, null, null) : req;

        if (user.getPasswordHash() != null) {
            requirePassword(user, body.password());
        } else {
            requirePasswordlessConfirmation(user, body);
        }

        userService.deleteMe(userId);
        mailer.sendDeletionScheduled(userId, user.getEmail(), user.getPreferredLanguage());
        log.info("Account {} scheduled for deletion", userId);
    }

    private void requirePassword(User user, String password) {
        if (password == null || password.isEmpty()) {
            throw ApiException.badRequest("PASSWORD_REQUIRED", "Enter your password to delete your account");
        }
        if (!passwordEncoder.matches(password, user.getPasswordHash())) {
            throw ApiException.badRequest("INVALID_PASSWORD", "Password is incorrect");
        }
    }

    private void requirePasswordlessConfirmation(User user, DeleteAccountRequest body) {
        if (body.googleIdToken() != null && !body.googleIdToken().isBlank()) {
            GoogleAuthService.GoogleUserInfo google;
            try {
                google = googleAuthService.verifyRecent(body.googleIdToken(), GOOGLE_REAUTH_MAX_AGE, Instant.now());
            } catch (ApiException e) {
                // A 401 here would look like an expired session to clients: report it as a bad confirmation
                throw new ApiException(HttpStatus.BAD_REQUEST, e.getCode(), e.getMessage());
            }
            if (user.getGoogleId() == null || !user.getGoogleId().equals(google.googleId())) {
                throw ApiException.badRequest("GOOGLE_ACCOUNT_MISMATCH",
                        "That Google account is not linked to this Meeple account");
            }
            return;
        }
        if (!AccountPolicy.DELETE_CONFIRMATION.equals(body.confirm())) {
            throw ApiException.badRequest("CONFIRMATION_REQUIRED",
                    "Type DELETE or sign in with Google again to confirm");
        }
    }
}
