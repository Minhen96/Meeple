package com.meeplehearth.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
@ConfigurationProperties(prefix = "app")
public class AppProperties {

    private Jwt jwt = new Jwt();
    private R2 r2 = new R2();
    private Cors cors = new Cors();

    public Jwt getJwt() {
        return jwt;
    }

    public void setJwt(Jwt jwt) {
        this.jwt = jwt;
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

    // --- Nested classes ---

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
}
