package com.meeplehearth.auth.service;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.config.AppProperties;
import org.springframework.stereotype.Service;

import java.util.Collections;

@Service
public class GoogleAuthService {

    private final GoogleIdTokenVerifier verifier;

    public GoogleAuthService(AppProperties appProperties) {
        String clientId = appProperties.getGoogle().getClientId();
        this.verifier = new GoogleIdTokenVerifier.Builder(
                new NetHttpTransport(), GsonFactory.getDefaultInstance())
                .setAudience(Collections.singletonList(clientId))
                .build();
    }

    public record GoogleUserInfo(
            String googleId,
            String email,
            String displayName,
            String avatarUrl
    ) {}

    public GoogleUserInfo verify(String idToken) {
        try {
            GoogleIdToken token = verifier.verify(idToken);
            if (token == null) {
                throw ApiException.unauthorized("INVALID_GOOGLE_TOKEN", "Invalid Google ID token");
            }
            GoogleIdToken.Payload payload = token.getPayload();
            return new GoogleUserInfo(
                    payload.getSubject(),
                    payload.getEmail(),
                    (String) payload.get("name"),
                    (String) payload.get("picture")
            );
        } catch (ApiException e) {
            throw e;
        } catch (Exception e) {
            throw ApiException.unauthorized("INVALID_GOOGLE_TOKEN", "Could not verify Google token");
        }
    }
}
