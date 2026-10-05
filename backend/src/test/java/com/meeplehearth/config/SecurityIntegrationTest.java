package com.meeplehearth.config;

import com.meeplehearth.support.auth.AuthWebIntegrationTest;
import com.meeplehearth.user.entity.User;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import jakarta.servlet.http.Cookie;
import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MvcResult;

import java.nio.charset.StandardCharsets;
import java.util.Date;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * The security filter chain end to end: JWT authentication from header or cookie, rejection of
 * forged / revoked tokens, role checks, actuator exposure, CORS and the Origin/Referer CSRF check.
 */
class SecurityIntegrationTest extends AuthWebIntegrationTest {

    private static final String ME = "/api/v1/users/me";

    @Autowired private AppProperties appProperties;

    private String signedToken(String subject, String type, int tokenVersion, Date expiration) {
        return Jwts.builder()
                .subject(subject)
                .claim("type", type)
                .claim("tv", tokenVersion)
                .issuedAt(new Date())
                .expiration(expiration)
                .signWith(Keys.hmacShaKeyFor(appProperties.getJwt().getSecret().getBytes(StandardCharsets.UTF_8)))
                .compact();
    }

    // ------------------------------------------------------------------ authentication

    @Test
    void bearerHeaderAndCookieBothAuthenticate() throws Exception {
        User user = persistUser(true);

        mockMvc.perform(get(ME).header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken(user)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.id").value(user.getId().toString()));
        mockMvc.perform(get(ME).cookie(new Cookie("theme", "dark"), accessCookie(user)))
                .andExpect(status().isOk());
    }

    @Test
    void nonBearerAuthorizationHeaderFallsBackToTheCookie() throws Exception {
        User user = persistUser(true);

        mockMvc.perform(get(ME).header(HttpHeaders.AUTHORIZATION, "Basic dXNlcjpwYXNz").cookie(accessCookie(user)))
                .andExpect(status().isOk());
        mockMvc.perform(get(ME).header(HttpHeaders.AUTHORIZATION, "Basic dXNlcjpwYXNz"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void unauthenticatedRequestsGetAJsonError() throws Exception {
        mockMvc.perform(get(ME).cookie(new Cookie("unrelated", "x")))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"))
                .andExpect(jsonPath("$.error").value("Authentication required"));
    }

    @Test
    void forgedExpiredMistypedAndRevokedTokensAreRejected() throws Exception {
        User user = persistUser(true);
        String id = user.getId().toString();
        Date inAnHour = new Date(System.currentTimeMillis() + 3_600_000);

        // Sanity check: a hand-made token with the right shape is accepted
        mockMvc.perform(get(ME).header(HttpHeaders.AUTHORIZATION, "Bearer " + signedToken(id, "access", 0, inAnHour)))
                .andExpect(status().isOk());

        String[] rejected = {
                "not-a-jwt",
                signedToken(id, "refresh", 0, inAnHour),
                signedToken(id, "access", 0, new Date(System.currentTimeMillis() - 1_000)),
                signedToken(id, "access", 7, inAnHour),
                signedToken("not-a-uuid", "access", 0, inAnHour),
                signedToken(java.util.UUID.randomUUID().toString(), "access", 0, inAnHour),
                Jwts.builder().subject(id).claim("type", "access")
                        .signWith(Keys.hmacShaKeyFor("another-secret-that-is-at-least-32-bytes!".getBytes(StandardCharsets.UTF_8)))
                        .compact()
        };
        for (String token : rejected) {
            mockMvc.perform(get(ME).header(HttpHeaders.AUTHORIZATION, "Bearer " + token))
                    .andExpect(status().isUnauthorized());
        }
    }

    @Test
    void publicEndpointsNeedNoToken() throws Exception {
        mockMvc.perform(get("/api/v1/auth/check-username").param("username", uniqueName()))
                .andExpect(status().isOk());
        // An invalid token on a public endpoint is ignored rather than rejected
        mockMvc.perform(get("/api/v1/auth/check-username").param("username", uniqueName())
                        .cookie(new Cookie("access_token", "garbage")))
                .andExpect(status().isOk());
    }

    // ------------------------------------------------------------------ actuator & docs

    @Test
    void healthIsPublicButOtherActuatorEndpointsAreAdminOnly() throws Exception {
        int health = mockMvc.perform(get("/actuator/health")).andReturn().getResponse().getStatus();
        assertThat(health).isNotIn(401, 403);

        mockMvc.perform(get("/actuator/info")).andExpect(status().isUnauthorized());
        mockMvc.perform(get("/actuator/info").cookie(accessCookie(persistUser(true)))).andExpect(status().isForbidden());
        mockMvc.perform(get("/actuator/info").cookie(accessCookie(persistAdmin()))).andExpect(status().isOk());
        mockMvc.perform(get("/actuator/metrics").cookie(accessCookie(persistUser(true)))).andExpect(status().isForbidden());
    }

    @Test
    void adminPathsRequireTheAdminRole() throws Exception {
        User user = persistUser(true);

        for (String path : new String[]{"/api/v1/games/import", "/api/v1/games/hydrate-images",
                "/api/v1/admin/users/" + user.getId() + "/promote"}) {
            mockMvc.perform(post(path)).andExpect(status().isUnauthorized());
            mockMvc.perform(post(path).cookie(accessCookie(user))).andExpect(status().isForbidden());
        }
    }

    @Test
    void apiDocsNeedNoAuthentication() throws Exception {
        int status = mockMvc.perform(get("/v3/api-docs")).andReturn().getResponse().getStatus();

        assertThat(status).isNotIn(401, 403);
    }

    @Test
    @Disabled("BUG: springdoc-openapi 2.6.0 is incompatible with Spring Framework 6.2 (Spring Boot 3.4.3): "
            + "GET /v3/api-docs fails with NoSuchMethodError ControllerAdviceBean.<init>(Object) and returns 500; "
            + "springdoc 2.7.0+ supports Spring Boot 3.4")
    void apiDocsAreServedWhenEnabled() throws Exception {
        mockMvc.perform(get("/v3/api-docs"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.openapi").exists());
    }

    // ------------------------------------------------------------------ CORS & CSRF

    @Test
    void corsPreflightAllowsTheConfiguredOriginWithCredentials() throws Exception {
        mockMvc.perform(options("/api/v1/auth/login")
                        .header(HttpHeaders.ORIGIN, ALLOWED_ORIGIN)
                        .header(HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD, "POST"))
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, ALLOWED_ORIGIN))
                .andExpect(header().string(HttpHeaders.ACCESS_CONTROL_ALLOW_CREDENTIALS, "true"));

        mockMvc.perform(options("/api/v1/auth/login")
                        .header(HttpHeaders.ORIGIN, "https://evil.example.com")
                        .header(HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD, "POST"))
                .andExpect(status().isForbidden())
                .andExpect(header().doesNotExist(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN));
    }

    @Test
    void crossSiteStateChangingRequestsAreRejected() throws Exception {
        User user = persistUser(true);
        String loginBody = json(Map.of("emailOrUsername", user.getUsername(), "password", PASSWORD));

        // Cross-site form post identified by Referer only (no Origin header)
        MvcResult byReferer = mockMvc.perform(post("/api/v1/auth/login").with(fromClientIp())
                        .header(HttpHeaders.REFERER, "https://evil.example.com/attack.html")
                        .contentType(MediaType.APPLICATION_JSON).content(loginBody))
                .andReturn();
        assertThat(byReferer.getResponse().getStatus()).isEqualTo(403);
        assertThat(body(byReferer).get("code").asText()).isEqualTo("INVALID_ORIGIN");
        assertThat(setCookieValue(byReferer.getResponse(), "access_token")).isNull();

        // Authenticated state change from a foreign origin is blocked before reaching the controller
        mockMvc.perform(post("/api/v1/auth/logout").cookie(accessCookie(user))
                        .header(HttpHeaders.REFERER, "http://localhost:5174/"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("INVALID_ORIGIN"));

        // Same request from the real frontend, and from a client that sends neither header, passes
        mockMvc.perform(post("/api/v1/auth/login").with(fromClientIp())
                        .header(HttpHeaders.ORIGIN, ALLOWED_ORIGIN)
                        .contentType(MediaType.APPLICATION_JSON).content(loginBody))
                .andExpect(status().isOk());
        mockMvc.perform(post("/api/v1/auth/login").with(fromClientIp())
                        .header(HttpHeaders.REFERER, ALLOWED_ORIGIN + "/auth/login")
                        .contentType(MediaType.APPLICATION_JSON).content(loginBody))
                .andExpect(status().isOk());
        mockMvc.perform(post("/api/v1/auth/login").with(fromClientIp())
                        .contentType(MediaType.APPLICATION_JSON).content(loginBody))
                .andExpect(status().isOk());

        // Safe methods are not subject to the check
        mockMvc.perform(get("/api/v1/auth/check-email").param("email", "x@example.test")
                        .header(HttpHeaders.REFERER, "https://evil.example.com/"))
                .andExpect(status().isOk());
    }
}
