package com.meeplehearth.auth.service;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.meeplehearth.common.exception.ApiException;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class GoogleAuthServiceTest {

    private static GoogleIdToken.Payload payload(Boolean emailVerified) {
        GoogleIdToken.Payload payload = new GoogleIdToken.Payload();
        payload.setSubject("google-sub-123");
        payload.setEmail("player@example.com");
        payload.setEmailVerified(emailVerified);
        payload.set("name", "Player One");
        return payload;
    }

    private static GoogleAuthService serviceReturning(GoogleIdToken.Payload payload) throws Exception {
        GoogleIdTokenVerifier verifier = mock(GoogleIdTokenVerifier.class);
        GoogleIdToken token = mock(GoogleIdToken.class);
        when(token.getPayload()).thenReturn(payload);
        when(verifier.verify("id-token")).thenReturn(token);
        return new GoogleAuthService(verifier);
    }

    @Test
    void rejectsUnverifiedEmail() throws Exception {
        GoogleAuthService service = serviceReturning(payload(false));

        assertThatThrownBy(() -> service.verify("id-token"))
                .isInstanceOf(ApiException.class)
                .extracting("code").isEqualTo("GOOGLE_EMAIL_NOT_VERIFIED");
    }

    @Test
    void rejectsMissingEmailVerifiedClaim() throws Exception {
        GoogleAuthService service = serviceReturning(payload(null));

        assertThatThrownBy(() -> service.verify("id-token"))
                .isInstanceOf(ApiException.class)
                .extracting("code").isEqualTo("GOOGLE_EMAIL_NOT_VERIFIED");
    }

    @Test
    void acceptsVerifiedEmail() throws Exception {
        GoogleAuthService.GoogleUserInfo info = serviceReturning(payload(true)).verify("id-token");

        assertThat(info.googleId()).isEqualTo("google-sub-123");
        assertThat(info.email()).isEqualTo("player@example.com");
        assertThat(info.displayName()).isEqualTo("Player One");
    }

    @Test
    void rejectsTokenTheVerifierRefuses() throws Exception {
        GoogleIdTokenVerifier verifier = mock(GoogleIdTokenVerifier.class);
        when(verifier.verify("id-token")).thenReturn(null);

        assertThatThrownBy(() -> new GoogleAuthService(verifier).verify("id-token"))
                .isInstanceOf(ApiException.class)
                .extracting("code").isEqualTo("INVALID_GOOGLE_TOKEN");
    }
}
