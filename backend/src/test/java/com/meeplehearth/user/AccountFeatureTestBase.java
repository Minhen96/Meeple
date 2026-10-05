package com.meeplehearth.user;

import com.meeplehearth.support.social.ApiIntegrationTestBase;
import jakarta.servlet.http.Cookie;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MvcResult;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicInteger;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Helpers for the account (WP5) API tests: users with real passwords and cookie handling. */
public abstract class AccountFeatureTestBase extends ApiIntegrationTestBase {

    protected static final String PASSWORD = "correct-horse-42";
    private static final AtomicInteger IP_SEQ = new AtomicInteger();

    @Autowired protected PasswordEncoder passwordEncoder;

    /** A verified user with {@link #PASSWORD}; returns its id. Username and email via {@link #username}. */
    protected UUID passwordUser() {
        UUID id = user();
        jdbc.update("UPDATE users SET password_hash = ?, email_verified = true WHERE id = ?",
                passwordEncoder.encode(PASSWORD), id);
        return id;
    }

    /** A verified Google-only user (no password). */
    protected UUID googleUser(String googleId) {
        UUID id = user();
        jdbc.update("UPDATE users SET google_id = ?, email_verified = true WHERE id = ?", googleId, id);
        return id;
    }

    protected String username(UUID id) {
        return string("SELECT username FROM users WHERE id = ?", id);
    }

    protected String email(UUID id) {
        return string("SELECT email FROM users WHERE id = ?", id);
    }

    /** A client IP unique to this call, so per-IP rate limits and lockouts never collide across tests. */
    protected static String freshIp() {
        int n = IP_SEQ.incrementAndGet();
        return "10.77." + ((n >> 8) & 0xff) + "." + (n & 0xff);
    }

    /** Logs in through the API from {@code userAgent}; returns the response (cookies in Set-Cookie). */
    protected MvcResult login(UUID userId, String userAgent) throws Exception {
        return mvc.perform(post("/api/v1/auth/login")
                        .with(request -> {
                            request.setRemoteAddr(freshIp());
                            return request;
                        })
                        .header("User-Agent", userAgent)
                        .contentType("application/json")
                        .content(toJson(Map.of("emailOrUsername", username(userId), "password", PASSWORD))))
                .andExpect(status().isOk())
                .andReturn();
    }

    /** Value of cookie {@code name} from the response's Set-Cookie headers, or null. */
    protected static String setCookie(MvcResult result, String name) {
        List<String> headers = result.getResponse().getHeaders("Set-Cookie");
        for (String header : headers) {
            String pair = header.split(";", 2)[0];
            int eq = pair.indexOf('=');
            if (eq > 0 && pair.substring(0, eq).trim().equals(name)) {
                return pair.substring(eq + 1).trim();
            }
        }
        return null;
    }

    protected static Cookie[] sessionCookies(MvcResult loginResult) {
        return new Cookie[]{
                new Cookie("access_token", setCookie(loginResult, "access_token")),
                new Cookie("refresh_token", setCookie(loginResult, "refresh_token"))
        };
    }
}
