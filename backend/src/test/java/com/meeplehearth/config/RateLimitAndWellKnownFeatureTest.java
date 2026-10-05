package com.meeplehearth.config;

import com.meeplehearth.support.social.ApiIntegrationTestBase;
import org.junit.jupiter.api.Test;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.RequestPostProcessor;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** The global rate limit through the real filter chain, and the /.well-known files. */
@TestPropertySource(properties = {
        "app.rate-limit.per-ip-per-minute=3",
        "app.rate-limit.per-user-per-minute=4",
        "app.deep-links.ios-app-id=ABCDE12345.com.meeplehearth.app",
        "app.deep-links.android-package=com.meeplehearth.app",
        "app.deep-links.android-sha256-fingerprints=AA:BB, CC:DD"
})
class RateLimitAndWellKnownFeatureTest extends ApiIntegrationTestBase {

    private static RequestPostProcessor from(String ip) {
        return request -> {
            request.setRemoteAddr(ip);
            return request;
        };
    }

    /** Sends up to {@code max} requests and returns the first 429 (robust to a window boundary mid-test). */
    private MvcResult firstRejected(int max, java.util.concurrent.Callable<MvcResult> call) throws Exception {
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
        String ip = "198.51.100." + (UUID.randomUUID().hashCode() & 0x7f);
        MvcResult rejected = firstRejected(9, () -> mvc.perform(get("/api/v1/auth/check-username")
                .param("username", "nobody_here").with(from(ip))).andReturn());
        assertThat(json(rejected).get("code").asText()).isEqualTo("RATE_LIMIT_EXCEEDED");
        assertThat(Integer.parseInt(rejected.getResponse().getHeader("Retry-After"))).isBetween(1, 60);
    }

    @Test
    void authenticatedUsersAreLimitedPerUser() throws Exception {
        UUID userId = user();
        MvcResult rejected = firstRejected(11, () -> mvc.perform(get("/api/v1/users/me")
                .with(as(userId)).with(from("192.0.2.1"))).andReturn());
        assertThat(rejected.getResponse().getHeader("Retry-After")).isNotBlank();
        // Another user from the same IP has their own budget
        mvc.perform(get("/api/v1/users/me").with(as(user())).with(from("192.0.2.1")))
                .andExpect(status().isOk());
    }

    @Test
    void wellKnownFilesAreServedUnauthenticatedAsRawJson() throws Exception {
        mvc.perform(get("/.well-known/apple-app-site-association"))
                .andExpect(status().isOk())
                .andExpect(header().string("Content-Type", org.hamcrest.Matchers.startsWith("application/json")))
                .andExpect(jsonPath("$.applinks.details[0].appIDs[0]").value("ABCDE12345.com.meeplehearth.app"))
                .andExpect(jsonPath("$.applinks.details[0].components[0]['/']").value("/library/*"));
        mvc.perform(get("/.well-known/assetlinks.json"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].target.package_name").value("com.meeplehearth.app"))
                .andExpect(jsonPath("$[0].target.sha256_cert_fingerprints[1]").value("CC:DD"))
                .andExpect(jsonPath("$[0].relation[0]").value("delegate_permission/common.handle_all_urls"));
    }
}
