package com.meeplehearth.config;

import com.meeplehearth.auth.service.UserDetailsServiceImpl;
import com.meeplehearth.auth.util.JwtUtil;
import org.junit.jupiter.api.Test;
import org.springframework.boot.context.properties.bind.Binder;
import org.springframework.boot.context.properties.source.MapConfigurationPropertySource;
import org.springframework.core.task.TaskExecutor;
import org.springframework.mock.env.MockEnvironment;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.cors.CorsConfiguration;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.PutObjectPresignRequest;

import java.time.Duration;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

/** Plain unit tests of the configuration classes' own logic. */
class ConfigBeansTest {

    private static AppProperties corsProps(String... origins) {
        AppProperties props = new AppProperties();
        props.getCors().setAllowedOrigins(List.of(origins));
        return props;
    }

    // ------------------------------------------------------------------ SecurityConfig

    private static SecurityConfig securityConfig(boolean openAdminFlag, String... profiles) {
        MockEnvironment env = new MockEnvironment();
        env.setActiveProfiles(profiles);
        SecurityConfig config = new SecurityConfig(corsProps("http://localhost:5173"), mock(JwtUtil.class),
                mock(UserDetailsServiceImpl.class), env, mock(com.meeplehearth.common.ratelimit.RedisRateLimiter.class));
        ReflectionTestUtils.setField(config, "openAdminEndpoints", openAdminFlag);
        return config;
    }

    @Test
    void adminEndpointsAreOpenOnlyWhenFlaggedUnderTheLocalProfile() {
        assertThat(securityConfig(false, "local").adminEndpointsOpen()).isFalse();
        assertThat(securityConfig(true, "local").adminEndpointsOpen()).isTrue();
        // A stray flag in a deployed environment is ignored
        assertThat(securityConfig(true, "prod").adminEndpointsOpen()).isFalse();
        assertThat(securityConfig(true, "staging").adminEndpointsOpen()).isFalse();
        assertThat(securityConfig(true).adminEndpointsOpen()).isFalse();
    }

    @Test
    void corsAllowsOnlyConfiguredOriginsWithCredentials() {
        SecurityConfig config = securityConfig(false, "local");
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/games");

        CorsConfiguration cors = config.corsConfigurationSource().getCorsConfiguration(request);

        assertThat(cors).isNotNull();
        assertThat(cors.getAllowedOrigins()).containsExactly("http://localhost:5173");
        assertThat(cors.getAllowCredentials()).isTrue();
        assertThat(cors.getAllowedMethods()).contains("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS");
        assertThat(cors.checkOrigin("https://evil.example.com")).isNull();
    }

    @Test
    void passwordsAreHashedWithBcryptCost12() {
        PasswordEncoder encoder = securityConfig(false).passwordEncoder();

        String hash = encoder.encode("secret-password");

        assertThat(hash).startsWith("$2a$12$");
        assertThat(encoder.matches("secret-password", hash)).isTrue();
        assertThat(encoder.matches("other", hash)).isFalse();
    }

    // ------------------------------------------------------------------ R2Config

    @Test
    void r2ClientsFallBackToPlaceholdersWhenUnconfigured() {
        AppProperties props = new AppProperties();
        props.getR2().setEndpoint(" ");
        props.getR2().setBucket("bucket");
        R2Config config = new R2Config(props);

        try (S3Client client = config.s3Client(); S3Presigner presigner = config.s3Presigner()) {
            assertThat(client.serviceClientConfiguration().endpointOverride()).hasValueSatisfying(
                    uri -> assertThat(uri.toString()).isEqualTo("https://placeholder.r2.dev"));
            String url = presign(presigner);
            assertThat(url).startsWith("https://").contains("placeholder.r2.dev").contains("X-Amz-Credential=placeholder");
        }
    }

    @Test
    void r2ClientsUseConfiguredEndpointAndCredentials() {
        AppProperties props = new AppProperties();
        props.getR2().setEndpoint("https://acct.r2.cloudflarestorage.com");
        props.getR2().setAccessKey("AKIDEXAMPLE");
        props.getR2().setSecretKey("secret");
        R2Config config = new R2Config(props);

        try (S3Client client = config.s3Client(); S3Presigner presigner = config.s3Presigner()) {
            assertThat(client.serviceClientConfiguration().endpointOverride()).hasValueSatisfying(
                    uri -> assertThat(uri.getHost()).isEqualTo("acct.r2.cloudflarestorage.com"));
            assertThat(client.serviceClientConfiguration().region().id()).isEqualTo("auto");
            assertThat(presign(presigner)).contains("acct.r2.cloudflarestorage.com").contains("X-Amz-Credential=AKIDEXAMPLE");
        }
    }

    private static String presign(S3Presigner presigner) {
        return presigner.presignPutObject(PutObjectPresignRequest.builder()
                        .signatureDuration(Duration.ofMinutes(1))
                        .putObjectRequest(PutObjectRequest.builder().bucket("bucket").key("k.png").build())
                        .build())
                .url().toString();
    }

    // ------------------------------------------------------------------ AsyncConfig

    @Test
    void asyncExecutorIsBoundedWithALargeQueue() {
        TaskExecutor executor = new AsyncConfig().taskExecutor();

        assertThat(executor).isInstanceOf(ThreadPoolTaskExecutor.class);
        ThreadPoolTaskExecutor pool = (ThreadPoolTaskExecutor) executor;
        try {
            assertThat(pool.getCorePoolSize()).isEqualTo(5);
            assertThat(pool.getMaxPoolSize()).isEqualTo(10);
            assertThat(pool.getQueueCapacity()).isEqualTo(10000);
            assertThat(pool.getThreadNamePrefix()).isEqualTo("ai-exec-");
        } finally {
            pool.shutdown();
        }
    }

    // ------------------------------------------------------------------ AppProperties

    @Test
    void appPropertiesBindFromConfigurationKeys() {
        Map<String, String> source = Map.ofEntries(
                Map.entry("app.jwt.secret", "s".repeat(40)),
                Map.entry("app.jwt.access-token-expiry-ms", "900000"),
                Map.entry("app.jwt.refresh-token-expiry-days", "30"),
                Map.entry("app.auth.cookie-domain", ".meeple.example.com"),
                Map.entry("app.r2.endpoint", "https://r2.example.com"),
                Map.entry("app.r2.access-key", "ak"),
                Map.entry("app.r2.secret-key", "sk"),
                Map.entry("app.r2.bucket", "media"),
                Map.entry("app.r2.public-url", "https://cdn.example.com"),
                Map.entry("app.cors.allowed-origins[0]", "https://meeple.example.com"),
                Map.entry("app.google.client-id", "client.apps.googleusercontent.com"),
                Map.entry("app.email.from", "hello@example.com"),
                Map.entry("app.storage.max-upload-bytes", "2048"),
                Map.entry("app.seed.csv-url", "https://example.com/games.csv"),
                Map.entry("app.ai.completion.base-url", "https://api.deepseek.com"),
                Map.entry("app.ai.completion.api-key", "ck"),
                Map.entry("app.ai.completion.model", "deepseek-chat"),
                Map.entry("app.ai.embedding.base-url", "https://api.openai.com"),
                Map.entry("app.ai.embedding.api-key", "ek"),
                Map.entry("app.ai.embedding.model", "text-embedding-3-small"));

        AppProperties props = new Binder(new MapConfigurationPropertySource(source))
                .bind("app", AppProperties.class).get();

        assertThat(props.getJwt().getSecret()).hasSize(40);
        assertThat(props.getJwt().getAccessTokenExpiryMs()).isEqualTo(900_000);
        assertThat(props.getJwt().getRefreshTokenExpiryDays()).isEqualTo(30);
        assertThat(props.getAuth().getCookieDomain()).isEqualTo(".meeple.example.com");
        assertThat(props.getR2().getEndpoint()).isEqualTo("https://r2.example.com");
        assertThat(props.getR2().getAccessKey()).isEqualTo("ak");
        assertThat(props.getR2().getSecretKey()).isEqualTo("sk");
        assertThat(props.getR2().getBucket()).isEqualTo("media");
        assertThat(props.getR2().getPublicUrl()).isEqualTo("https://cdn.example.com");
        assertThat(props.getCors().getAllowedOrigins()).containsExactly("https://meeple.example.com");
        assertThat(props.getGoogle().getClientId()).isEqualTo("client.apps.googleusercontent.com");
        assertThat(props.getEmail().getFrom()).isEqualTo("hello@example.com");
        assertThat(props.getStorage().getMaxUploadBytes()).isEqualTo(2048);
        assertThat(props.getSeed().getCsvUrl()).isEqualTo("https://example.com/games.csv");
        assertThat(props.getAi().getCompletion().getBaseUrl()).isEqualTo("https://api.deepseek.com");
        assertThat(props.getAi().getCompletion().getApiKey()).isEqualTo("ck");
        assertThat(props.getAi().getCompletion().getModel()).isEqualTo("deepseek-chat");
        assertThat(props.getAi().getEmbedding().getBaseUrl()).isEqualTo("https://api.openai.com");
        assertThat(props.getAi().getEmbedding().getApiKey()).isEqualTo("ek");
        assertThat(props.getAi().getEmbedding().getModel()).isEqualTo("text-embedding-3-small");
    }

    @Test
    void appPropertiesDefaults() {
        AppProperties props = new AppProperties();

        assertThat(props.getCors().getAllowedOrigins()).isEmpty();
        assertThat(props.getGoogle().getClientId()).isEmpty();
        assertThat(props.getEmail().getFrom()).isEqualTo("noreply@meeple.yapminhen.com");
        assertThat(props.getStorage().getMaxUploadBytes()).isEqualTo(10L * 1024 * 1024);
        assertThat(props.getAuth().getCookieDomain()).isNull();

        // Whole sections can be replaced (as the binder does for nested objects)
        AppProperties.Jwt jwt = new AppProperties.Jwt();
        AppProperties.Auth auth = new AppProperties.Auth();
        AppProperties.R2 r2 = new AppProperties.R2();
        AppProperties.Cors cors = new AppProperties.Cors();
        AppProperties.Google google = new AppProperties.Google();
        AppProperties.Email email = new AppProperties.Email();
        AppProperties.Ai ai = new AppProperties.Ai();
        AppProperties.Seed seed = new AppProperties.Seed();
        AppProperties.Storage storage = new AppProperties.Storage();
        ai.setCompletion(new AppProperties.Ai.Completion());
        ai.setEmbedding(new AppProperties.Ai.Embedding());
        props.setJwt(jwt);
        props.setAuth(auth);
        props.setR2(r2);
        props.setCors(cors);
        props.setGoogle(google);
        props.setEmail(email);
        props.setAi(ai);
        props.setSeed(seed);
        props.setStorage(storage);

        assertThat(props.getJwt()).isSameAs(jwt);
        assertThat(props.getAuth()).isSameAs(auth);
        assertThat(props.getR2()).isSameAs(r2);
        assertThat(props.getCors()).isSameAs(cors);
        assertThat(props.getGoogle()).isSameAs(google);
        assertThat(props.getEmail()).isSameAs(email);
        assertThat(props.getAi()).isSameAs(ai);
        assertThat(props.getSeed()).isSameAs(seed);
        assertThat(props.getStorage()).isSameAs(storage);
    }
}
