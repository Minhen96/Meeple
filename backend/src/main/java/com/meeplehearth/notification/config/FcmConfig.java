package com.meeplehearth.notification.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import com.meeplehearth.config.AppProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Base64;

/**
 * Firebase Admin for FCM. {@code FIREBASE_SERVICE_ACCOUNT_JSON} ({@code app.fcm.service-account-json})
 * holds the service-account JSON, raw or base64-encoded. When it is blank, or cannot be parsed,
 * no {@link FirebaseMessaging} bean exists and push sending is a logged no-op; the application
 * still starts.
 */
@Configuration
public class FcmConfig {

    private static final Logger log = LoggerFactory.getLogger(FcmConfig.class);

    static final String APP_NAME = "meeple-fcm";

    /** Returns null (no bean) when push is not configured. */
    @Bean
    public FirebaseMessaging firebaseMessaging(AppProperties appProperties) {
        String secret = appProperties.getFcm().getServiceAccountJson();
        if (secret == null || secret.isBlank()) {
            log.info("FCM disabled: FIREBASE_SERVICE_ACCOUNT_JSON is not set; push notifications are a no-op");
            return null;
        }
        try {
            byte[] json = decodeServiceAccount(secret);
            FirebaseApp app = FirebaseApp.getApps().stream()
                    .filter(a -> APP_NAME.equals(a.getName()))
                    .findFirst()
                    .orElseGet(() -> initialize(json));
            log.info("FCM enabled");
            return FirebaseMessaging.getInstance(app);
        } catch (RuntimeException e) {
            // Never include the secret: only the failure type
            log.error("FCM disabled: FIREBASE_SERVICE_ACCOUNT_JSON could not be loaded ({})",
                    e.getClass().getSimpleName());
            return null;
        }
    }

    private static FirebaseApp initialize(byte[] json) {
        try {
            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(new ByteArrayInputStream(json)))
                    .build();
            return FirebaseApp.initializeApp(options, APP_NAME);
        } catch (IOException e) {
            throw new IllegalStateException("Invalid Firebase service account", e);
        }
    }

    /** Raw JSON (starts with '{') or base64 (standard or URL-safe, line breaks allowed). */
    static byte[] decodeServiceAccount(String secret) {
        String trimmed = secret.trim();
        if (trimmed.startsWith("{")) {
            return trimmed.getBytes(StandardCharsets.UTF_8);
        }
        String compact = trimmed.replaceAll("\\s", "");
        byte[] decoded;
        try {
            decoded = Base64.getDecoder().decode(compact);
        } catch (IllegalArgumentException e) {
            decoded = Base64.getUrlDecoder().decode(compact);
        }
        String text = new String(decoded, StandardCharsets.UTF_8).trim();
        if (!text.startsWith("{")) {
            throw new IllegalArgumentException("Decoded service account is not JSON");
        }
        return text.getBytes(StandardCharsets.UTF_8);
    }
}
