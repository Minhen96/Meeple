package com.meeplehearth.auth.service;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.meeplehearth.common.exception.ApiException;
import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.time.Instant;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/** Google re-authentication for account deletion: the ID token must be recent. */
class GoogleReauthFeatureTest {

    private static final Instant NOW = Instant.parse("2026-10-05T12:00:00Z");

    private static GoogleAuthService serviceIssuedAt(Long issuedAtSeconds) throws Exception {
        GoogleIdToken.Payload payload = new GoogleIdToken.Payload();
        payload.setSubject("sub-1");
        payload.setEmail("p@example.com");
        payload.setEmailVerified(true);
        payload.setIssuedAtTimeSeconds(issuedAtSeconds);
        GoogleIdTokenVerifier verifier = mock(GoogleIdTokenVerifier.class);
        GoogleIdToken token = mock(GoogleIdToken.class);
        when(token.getPayload()).thenReturn(payload);
        when(verifier.verify("t")).thenReturn(token);
        return new GoogleAuthService(verifier);
    }

    @Test
    void acceptsATokenIssuedMomentsAgo() throws Exception {
        GoogleAuthService service = serviceIssuedAt(NOW.minusSeconds(30).getEpochSecond());
        assertThat(service.verifyRecent("t", Duration.ofMinutes(10), NOW).googleId()).isEqualTo("sub-1");
    }

    @Test
    void rejectsAnOldOrUndatedToken() throws Exception {
        GoogleAuthService old = serviceIssuedAt(NOW.minus(Duration.ofMinutes(11)).getEpochSecond());
        assertThatThrownBy(() -> old.verifyRecent("t", Duration.ofMinutes(10), NOW))
                .isInstanceOf(ApiException.class)
                .extracting("code").isEqualTo("GOOGLE_REAUTH_REQUIRED");

        GoogleAuthService undated = serviceIssuedAt(null);
        assertThatThrownBy(() -> undated.verifyRecent("t", Duration.ofMinutes(10), NOW))
                .isInstanceOf(ApiException.class)
                .extracting("code").isEqualTo("GOOGLE_REAUTH_REQUIRED");
    }
}
