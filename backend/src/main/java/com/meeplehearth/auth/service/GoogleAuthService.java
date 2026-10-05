package com.meeplehearth.auth.service;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.config.AppProperties;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.Collections;

@Service
public class GoogleAuthService {

    private final GoogleIdTokenVerifier verifier;

    @Autowired
    public GoogleAuthService(AppProperties appProperties) {
        this(new GoogleIdTokenVerifier.Builder(
                new NetHttpTransport(), GsonFactory.getDefaultInstance())
                .setAudience(Collections.singletonList(appProperties.getGoogle().getClientId()))
                .build());
    }

    GoogleAuthService(GoogleIdTokenVerifier verifier) {
        this.verifier = verifier;
    }

    public record GoogleUserInfo(
            String googleId,
            String email,
            String displayName,
            String avatarUrl
    ) {}

    public GoogleUserInfo verify(String idToken) {
        return toUserInfo(verifiedToken(idToken).getPayload());
    }

    /**
     * Re-authentication for sensitive actions (account deletion): the token must verify and have
     * been issued within {@code maxAge}, so an old token captured elsewhere cannot be replayed.
     */
    public GoogleUserInfo verifyRecent(String idToken, Duration maxAge, Instant now) {
        GoogleIdToken token = verifiedToken(idToken);
        Long issuedAt = token.getPayload() == null ? null : token.getPayload().getIssuedAtTimeSeconds();
        if (issuedAt == null || Instant.ofEpochSecond(issuedAt).isBefore(now.minus(maxAge))) {
            throw ApiException.unauthorized("GOOGLE_REAUTH_REQUIRED", "Please sign in with Google again");
        }
        return toUserInfo(token.getPayload());
    }

    private GoogleIdToken verifiedToken(String idToken) {
        GoogleIdToken token;
        try {
            token = verifier.verify(idToken);
        } catch (Exception e) {
            throw ApiException.unauthorized("INVALID_GOOGLE_TOKEN", "Could not verify Google token");
        }
        if (token == null) {
            throw ApiException.unauthorized("INVALID_GOOGLE_TOKEN", "Invalid Google ID token");
        }
        return token;
    }

    /**
     * Only a Google-verified email may be trusted: it is used to link to existing accounts,
     * so an unverified one would let anyone claim an arbitrary address.
     */
    static GoogleUserInfo toUserInfo(GoogleIdToken.Payload payload) {
        if (payload == null || payload.getSubject() == null || payload.getSubject().isBlank()) {
            throw ApiException.unauthorized("INVALID_GOOGLE_TOKEN", "Invalid Google ID token");
        }
        String email = payload.getEmail();
        if (email == null || email.isBlank() || !Boolean.TRUE.equals(payload.getEmailVerified())) {
            throw ApiException.unauthorized("GOOGLE_EMAIL_NOT_VERIFIED",
                    "Your Google account email address is not verified");
        }
        return new GoogleUserInfo(
                payload.getSubject(),
                email,
                (String) payload.get("name"),
                (String) payload.get("picture")
        );
    }
}
