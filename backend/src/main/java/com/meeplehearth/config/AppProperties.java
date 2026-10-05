package com.meeplehearth.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
@ConfigurationProperties(prefix = "app")
public class AppProperties {

    private Jwt jwt = new Jwt();
    private Auth auth = new Auth();
    private R2 r2 = new R2();
    private Cors cors = new Cors();
    private Google google = new Google();
    private Email email = new Email();
    private Ai ai = new Ai();
    private Seed seed = new Seed();
    private Storage storage = new Storage();
    private Fcm fcm = new Fcm();
    private Bgg bgg = new Bgg();

    public Jwt getJwt() {
        return jwt;
    }

    public void setJwt(Jwt jwt) {
        this.jwt = jwt;
    }

    public Auth getAuth() {
        return auth;
    }

    public void setAuth(Auth auth) {
        this.auth = auth;
    }

    public R2 getR2() {
        return r2;
    }

    public void setR2(R2 r2) {
        this.r2 = r2;
    }

    public Cors getCors() {
        return cors;
    }

    public void setCors(Cors cors) {
        this.cors = cors;
    }

    public Google getGoogle() {
        return google;
    }

    public void setGoogle(Google google) {
        this.google = google;
    }

    public Email getEmail() {
        return email;
    }

    public void setEmail(Email email) {
        this.email = email;
    }

    public Ai getAi() {
        return ai;
    }

    public void setAi(Ai ai) {
        this.ai = ai;
    }

    // --- Nested classes ---

    public static class Auth {
        private String cookieDomain;

        public String getCookieDomain() {
            return cookieDomain;
        }

        public void setCookieDomain(String cookieDomain) {
            this.cookieDomain = cookieDomain;
        }
    }

    public static class Jwt {
        private String secret;
        private long accessTokenExpiryMs;
        private int refreshTokenExpiryDays;

        public String getSecret() {
            return secret;
        }

        public void setSecret(String secret) {
            this.secret = secret;
        }

        public long getAccessTokenExpiryMs() {
            return accessTokenExpiryMs;
        }

        public void setAccessTokenExpiryMs(long accessTokenExpiryMs) {
            this.accessTokenExpiryMs = accessTokenExpiryMs;
        }

        public int getRefreshTokenExpiryDays() {
            return refreshTokenExpiryDays;
        }

        public void setRefreshTokenExpiryDays(int refreshTokenExpiryDays) {
            this.refreshTokenExpiryDays = refreshTokenExpiryDays;
        }
    }

    public static class R2 {
        private String endpoint;
        private String accessKey;
        private String secretKey;
        private String bucket;
        private String publicUrl;

        public String getEndpoint() {
            return endpoint;
        }

        public void setEndpoint(String endpoint) {
            this.endpoint = endpoint;
        }

        public String getAccessKey() {
            return accessKey;
        }

        public void setAccessKey(String accessKey) {
            this.accessKey = accessKey;
        }

        public String getSecretKey() {
            return secretKey;
        }

        public void setSecretKey(String secretKey) {
            this.secretKey = secretKey;
        }

        public String getBucket() {
            return bucket;
        }

        public void setBucket(String bucket) {
            this.bucket = bucket;
        }

        public String getPublicUrl() {
            return publicUrl;
        }

        public void setPublicUrl(String publicUrl) {
            this.publicUrl = publicUrl;
        }
    }

    public static class Cors {
        private List<String> allowedOrigins = List.of();

        public List<String> getAllowedOrigins() {
            return allowedOrigins;
        }

        public void setAllowedOrigins(List<String> allowedOrigins) {
            this.allowedOrigins = allowedOrigins;
        }
    }

    public static class Google {
        private String clientId = "";

        public String getClientId() {
            return clientId;
        }

        public void setClientId(String clientId) {
            this.clientId = clientId;
        }
    }

    public static class Email {
        private String from = "noreply@meeple.yapminhen.com";

        public String getFrom() {
            return from;
        }

        public void setFrom(String from) {
            this.from = from;
        }
    }

    public Storage getStorage() { return storage; }
    public void setStorage(Storage s) { this.storage = s; }

    /** Limits for user image uploads (presigned PUT and multipart). */
    public static class Storage {
        private long maxUploadBytes = 10L * 1024 * 1024;
        public long getMaxUploadBytes() { return maxUploadBytes; }
        public void setMaxUploadBytes(long v) { this.maxUploadBytes = v; }
    }

    public Seed getSeed() { return seed; }
    public void setSeed(Seed s) { this.seed = s; }

    public static class Seed {
        private String csvUrl;
        public String getCsvUrl() { return csvUrl; }
        public void setCsvUrl(String v) { this.csvUrl = v; }
    }

    /**
     * AI provider config — provider-agnostic.
     *
     * Completion and embedding are configured separately so providers can be mixed:
     *   e.g. DeepSeek for chat + OpenAI for embeddings.
     *
     * All values come from application.yml / application-local.yml — nothing hardcoded here.
     *
     * Supported (OpenAI-compatible REST format — Bearer token):
     *   OpenAI:   https://api.openai.com
     *   DeepSeek: https://api.deepseek.com
     *   Groq:     https://api.groq.com/openai
     *   Together: https://api.together.xyz
     */
    public static class Ai {
        private Completion completion = new Completion();
        private Embedding embedding = new Embedding();

        public Completion getCompletion() { return completion; }
        public void setCompletion(Completion c) { this.completion = c; }

        public Embedding getEmbedding() { return embedding; }
        public void setEmbedding(Embedding e) { this.embedding = e; }

        public static class Completion {
            private String baseUrl;
            private String apiKey;
            private String model;

            public String getBaseUrl() { return baseUrl; }
            public void setBaseUrl(String v) { this.baseUrl = v; }

            public String getApiKey() { return apiKey; }
            public void setApiKey(String v) { this.apiKey = v; }

            public String getModel() { return model; }
            public void setModel(String v) { this.model = v; }
        }

        public static class Embedding {
            private String baseUrl;
            private String apiKey;
            private String model;

            public String getBaseUrl() { return baseUrl; }
            public void setBaseUrl(String v) { this.baseUrl = v; }

            public String getApiKey() { return apiKey; }
            public void setApiKey(String v) { this.apiKey = v; }

            public String getModel() { return model; }
            public void setModel(String v) { this.model = v; }
        }
    }

    public Fcm getFcm() { return fcm; }
    public void setFcm(Fcm f) { this.fcm = f; }

    /** Firebase Cloud Messaging. A blank service account disables push sending (no-op). */
    public static class Fcm {
        private String serviceAccountJson = "";
        public String getServiceAccountJson() { return serviceAccountJson; }
        public void setServiceAccountJson(String v) { this.serviceAccountJson = v; }
        public boolean isEnabled() { return serviceAccountJson != null && !serviceAccountJson.isBlank(); }
    }

    private RateLimit rateLimit = new RateLimit();
    private DeepLinks deepLinks = new DeepLinks();

    public RateLimit getRateLimit() { return rateLimit; }
    public void setRateLimit(RateLimit r) { this.rateLimit = r; }

    public DeepLinks getDeepLinks() { return deepLinks; }
    public void setDeepLinks(DeepLinks d) { this.deepLinks = d; }

    /**
     * Global API rate limits (FEATURES_COMPLETE section 12.6), per one-minute window:
     * authenticated requests per user, unauthenticated requests per client IP, and the stricter
     * login / reactivation limit per client IP.
     */
    public static class RateLimit {
        private boolean enabled = true;
        private long perUserPerMinute = 200;
        private long perIpPerMinute = 20;
        private long loginPerMinute = 10;

        public boolean isEnabled() { return enabled; }
        public void setEnabled(boolean v) { this.enabled = v; }
        public long getPerUserPerMinute() { return perUserPerMinute; }
        public void setPerUserPerMinute(long v) { this.perUserPerMinute = v; }
        public long getPerIpPerMinute() { return perIpPerMinute; }
        public void setPerIpPerMinute(long v) { this.perIpPerMinute = v; }
        public long getLoginPerMinute() { return loginPerMinute; }
        public void setLoginPerMinute(long v) { this.loginPerMinute = v; }
    }

    /**
     * App links / universal links served under /.well-known (FEATURES_COMPLETE section 12.3).
     * Empty values publish valid files with no apps.
     */
    public static class DeepLinks {
        /** iOS app id: {@code <TeamID>.<bundle id>}. */
        private String iosAppId = "";
        private String androidPackage = "";
        /** Comma-separated SHA-256 signing certificate fingerprints ("AB:CD:..."). */
        private String androidSha256Fingerprints = "";

        public String getIosAppId() { return iosAppId; }
        public void setIosAppId(String v) { this.iosAppId = v; }
        public String getAndroidPackage() { return androidPackage; }
        public void setAndroidPackage(String v) { this.androidPackage = v; }
        public String getAndroidSha256Fingerprints() { return androidSha256Fingerprints; }
        public void setAndroidSha256Fingerprints(String v) { this.androidSha256Fingerprints = v; }
    }

    public Bgg getBgg() { return bgg; }
    public void setBgg(Bgg b) { this.bgg = b; }

    /** BoardGameGeek. xmlapi2/collection requires a registered application token. */
    public static class Bgg {
        private String apiToken = "";
        public String getApiToken() { return apiToken; }
        public void setApiToken(String v) { this.apiToken = v; }
        public boolean hasApiToken() { return apiToken != null && !apiToken.isBlank(); }
    }
}
