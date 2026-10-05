package com.meeplehearth.config;

import com.meeplehearth.user.AccountFeatureTestBase;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.RequestPostProcessor;

import java.util.UUID;
import java.util.concurrent.Callable;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * The global rate limit through the real filter chain, and the /.well-known files. Limits are
 * lowered on the live properties object for each test (the filter reads it per request) instead
 * of starting a separate application context.
 */
class RateLimitAndWellKnownFeatureTest extends AccountFeatureTestBase {

    @Autowired AppProperties appProperties;
    private long savedPerIp;
    private long savedPerUser;

    @BeforeEach
    void lowerLimits() {
        AppProperties.RateLimit limits = appProperties.getRateLimit();
        savedPerIp = limits.getPerIpPerMinute();
        savedPerUser = limits.getPerUserPerMinute();
        limits.setPerIpPerMinute(3);
        limits.setPerUserPerMinute(4);
    }

    @AfterEach
    void restoreLimits() {
        appProperties.getRateLimit().setPerIpPerMinute(savedPerIp);
        appProperties.getRateLimit().setPerUserPerMinute(savedPerUser);
    }

    private static RequestPostProcessor from(String ip) {
        return request -> {
            request.setRemoteAddr(ip);
            return request;
        };
    }

    /** Sends up to {@code max} requests and returns the first 429 (robust to a window boundary mid-test). */
    private MvcResult firstRejected(int max, Callable<MvcResult> call) throws Exception {
        for (int i = 0; i < max; i++) {
            MvcResult result = call.call();
            if (result.getResponse().getStatus() == 429) {
                return result;
            }
            assertThat(result.getResponse().getStatus()).isEqualTo(200);
        }
        throw new AssertionError("No request was rate limited");
    }

    @Test
    void unauthenticatedClientsAreLimitedPerIp() throws Exception {
        String ip = freshIp();
        MvcResult rejected = firstRejected(9, () -> mvc.perform(get("/api/v1/auth/check-username")
                .param("username", "nobody_here").with(from(ip))).andReturn());
        assertThat(json(rejected).get("code").asText()).isEqualTo("RATE_LIMIT_EXCEEDED");
        assertThat(Integer.parseInt(rejected.getResponse().getHeader("Retry-After"))).isBetween(1, 60);
    }

    @Test
    void authenticatedUsersAreLimitedPerUser() throws Exception {
        UUID userId = user();
        String ip = freshIp();
        MvcResult rejected = firstRejected(11, () -> mvc.perform(get("/api/v1/users/me")
                .with(as(userId)).with(from(ip))).andReturn());
        assertThat(rejected.getResponse().getHeader("Retry-After")).isNotBlank();
        // Another user from the same IP has their own budget
        mvc.perform(get("/api/v1/users/me").with(as(user())).with(from(ip)))
                .andExpect(status().isOk());
    }

    @Test
    void wellKnownFilesAreServedUnauthenticatedAsRawJson() throws Exception {
        mvc.perform(get("/.well-known/apple-app-site-association"))
                .andExpect(status().isOk())
                .andExpect(header().string("Content-Type", org.hamcrest.Matchers.startsWith("application/json")))
                .andExpect(jsonPath("$.applinks.details").isArray());
        mvc.perform(get("/.well-known/assetlinks.json"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray());

        AppProperties.DeepLinks links = appProperties.getDeepLinks();
        try {
            links.setIosAppId("ABCDE12345.com.meeplehearth.app");
            links.setAndroidPackage("com.meeplehearth.app");
            links.setAndroidSha256Fingerprints("AA:BB, CC:DD");
            mvc.perform(get("/.well-known/apple-app-site-association"))
                    .andExpect(jsonPath("$.applinks.details[0].appIDs[0]").value("ABCDE12345.com.meeplehearth.app"))
                    .andExpect(jsonPath("$.applinks.details[0].components[0]['/']").value("/library/*"));
            mvc.perform(get("/.well-known/assetlinks.json"))
                    .andExpect(jsonPath("$[0].target.package_name").value("com.meeplehearth.app"))
                    .andExpect(jsonPath("$[0].target.sha256_cert_fingerprints[1]").value("CC:DD"))
                    .andExpect(jsonPath("$[0].relation[0]").value("delegate_permission/common.handle_all_urls"));
        } finally {
            links.setIosAppId("");
            links.setAndroidPackage("");
            links.setAndroidSha256Fingerprints("");
        }
    }
}
