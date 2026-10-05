package com.meeplehearth.user.service;

import com.meeplehearth.auth.service.GoogleAuthService;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.user.dto.DeleteAccountRequest;
import com.meeplehearth.user.entity.User;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.Duration;
import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Google re-authentication path of account deletion (C11). */
class AccountDeletionServiceFeatureTest {

    private final UserService userService = mock(UserService.class);
    private final GoogleAuthService google = mock(GoogleAuthService.class);
    private final AccountMailer mailer = mock(AccountMailer.class);
    private final AccountDeletionService service =
            new AccountDeletionService(userService, mock(PasswordEncoder.class), google, mailer);
    private final UUID userId = UUID.randomUUID();
    private final User user = new User();

    @BeforeEach
    void setUp() {
        user.setId(userId);
        user.setEmail("g@example.com");
        user.setGoogleId("sub-1");
        when(userService.findActiveUser(userId)).thenReturn(user);
    }

    @Test
    void deletesWithAFreshTokenForTheLinkedGoogleAccount() {
        when(google.verifyRecent(eq("tok"), any(Duration.class), any(Instant.class)))
                .thenReturn(new GoogleAuthService.GoogleUserInfo("sub-1", "g@example.com", "G", null));

        service.deleteAccount(userId, new DeleteAccountRequest(null, "tok", null));

        verify(userService).deleteMe(userId);
        verify(mailer).sendDeletionScheduled(userId, "g@example.com", "en");
    }

    @Test
    void refusesAnotherGoogleAccount() {
        when(google.verifyRecent(eq("tok"), any(Duration.class), any(Instant.class)))
                .thenReturn(new GoogleAuthService.GoogleUserInfo("sub-2", "x@example.com", "X", null));

        assertThatThrownBy(() -> service.deleteAccount(userId, new DeleteAccountRequest(null, "tok", null)))
                .isInstanceOf(ApiException.class)
                .extracting("code").isEqualTo("GOOGLE_ACCOUNT_MISMATCH");
        verify(userService, never()).deleteMe(any());
    }

    @Test
    void reportsGoogleFailuresAsBadRequests() {
        when(google.verifyRecent(eq("old"), any(Duration.class), any(Instant.class)))
                .thenThrow(ApiException.unauthorized("GOOGLE_REAUTH_REQUIRED", "again"));

        assertThatThrownBy(() -> service.deleteAccount(userId, new DeleteAccountRequest(null, "old", null)))
                .isInstanceOfSatisfying(ApiException.class, e -> {
                    assertThat(e.getStatus()).isEqualTo(HttpStatus.BAD_REQUEST);
                    assertThat(e.getCode()).isEqualTo("GOOGLE_REAUTH_REQUIRED");
                });
        verify(mailer, never()).sendDeletionScheduled(any(), anyString(), anyString());
    }

    @Test
    void nullBodyNeedsConfirmation() {
        assertThatThrownBy(() -> service.deleteAccount(userId, null))
                .isInstanceOf(ApiException.class)
                .extracting("code").isEqualTo("CONFIRMATION_REQUIRED");
    }
}
