package com.meeplehearth.support.auth;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.meeplehearth.auth.service.GoogleAuthService;
import com.meeplehearth.auth.util.JwtUtil;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import jakarta.mail.BodyPart;
import jakarta.mail.Multipart;
import jakarta.mail.Session;
import jakarta.mail.internet.MimeMessage;
import jakarta.persistence.EntityManager;
import jakarta.servlet.http.Cookie;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.redis.core.Cursor;
import org.springframework.data.redis.core.ScanOptions;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mail.javamail.JavaMailSenderImpl;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.RequestPostProcessor;
import org.springframework.transaction.annotation.Transactional;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.HexFormat;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.mockito.Mockito.atLeast;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Base class for HTTP-level integration tests of the auth, user, storage and notification APIs.
 * <p>
 * Runs the full application context against the real Postgres and Redis configured for the
 * test run. Each test runs in a transaction that is rolled back, so every row a request writes
 * disappears afterwards. Redis keys are not transactional: each test uses its own client IP
 * and the keys it creates are deleted in {@link #cleanUpRedis()}.
 * <p>
 * Only services outside our infrastructure are replaced: the mail sender, Google ID token
 * verification and the R2 (S3) clients. Every subclass shares this exact configuration, so
 * they all reuse one cached application context.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Transactional
@TestPropertySource(properties = {
        // The local profile opens admin endpoints for convenience; tests need production authz
        "app.security.open-admin-endpoints=false"
})
public abstract class AuthWebIntegrationTest {

    protected static final String PASSWORD = "correct-horse-battery";
    protected static final String ALLOWED_ORIGIN = "http://localhost:5173";

    private static final Pattern EMAIL_TOKEN = Pattern.compile("token=([0-9a-f]{64})");

    @Autowired protected MockMvc mockMvc;
    @Autowired protected ObjectMapper objectMapper;
    @Autowired protected UserRepository userRepository;
    @Autowired protected JwtUtil jwtUtil;
    @Autowired protected PasswordEncoder passwordEncoder;
    @Autowired protected StringRedisTemplate redis;
    @Autowired protected JdbcTemplate jdbc;
    @Autowired protected EntityManager entityManager;

    @MockitoBean protected JavaMailSenderImpl mailSender;
    @MockitoBean protected GoogleAuthService googleAuthService;
    @MockitoBean protected S3Client s3Client;
    @MockitoBean protected S3Presigner s3Presigner;

    /** Unique per test so IP-scoped rate limits and lockouts never leak between tests. */
    protected String clientIp;
    private final List<String> trackedEmails = new ArrayList<>();
    private final List<String> trackedKeys = new ArrayList<>();
    private String encodedPassword;

    @BeforeEach
    void setUpAuthWebIntegrationTest() {
        ThreadLocalRandom random = ThreadLocalRandom.current();
        clientIp = "10." + random.nextInt(1, 255) + "." + random.nextInt(1, 255) + "." + random.nextInt(1, 255);
        when(mailSender.createMimeMessage()).thenAnswer(inv -> new MimeMessage((Session) null));
    }

    @AfterEach
    void cleanUpRedis() {
        List<String> keys = new ArrayList<>(trackedKeys);
        keys.addAll(scan("auth:*:" + clientIp));
        for (String email : trackedEmails) {
            keys.addAll(scan("auth:ratelimit:*:email:" + sha256(email.trim().toLowerCase())));
        }
        if (!keys.isEmpty()) {
            redis.delete(keys);
        }
    }

    private List<String> scan(String pattern) {
        List<String> keys = new ArrayList<>();
        try (Cursor<String> cursor = redis.scan(ScanOptions.scanOptions().match(pattern).count(500).build())) {
            cursor.forEachRemaining(keys::add);
        }
        return keys;
    }

    // ------------------------------------------------------------------ fixtures

    /** Marks an email whose rate-limit counters must be removed after the test. */
    protected String trackEmail(String email) {
        trackedEmails.add(email);
        return email;
    }

    /** Marks an arbitrary Redis key for deletion after the test. */
    protected void trackRedisKey(String key) {
        trackedKeys.add(key);
    }

    protected static String uniqueName() {
        return "t" + UUID.randomUUID().toString().replace("-", "").substring(0, 12);
    }

    protected User persistUser(boolean emailVerified) {
        return persistUser(uniqueName(), emailVerified, "USER");
    }

    protected User persistUser(String username, boolean emailVerified, String role) {
        if (encodedPassword == null) {
            encodedPassword = passwordEncoder.encode(PASSWORD);
        }
        User user = new User();
        user.setUsername(username);
        user.setDisplayName("Display " + username);
        user.setEmail(trackEmail(username + "@example.test"));
        user.setPasswordHash(encodedPassword);
        user.setEmailVerified(emailVerified);
        user.setRole(role);
        return userRepository.saveAndFlush(user);
    }

    protected User persistAdmin() {
        return persistUser(uniqueName(), true, "ADMIN");
    }

    protected User reload(UUID id) {
        entityManager.flush();
        entityManager.clear();
        return userRepository.findById(id).orElseThrow();
    }

    protected String accessToken(User user) {
        return jwtUtil.generateAccessToken(user.getId(), user.getTokenVersion());
    }

    protected Cookie accessCookie(User user) {
        return new Cookie("access_token", accessToken(user));
    }

    /** Sets the client address the controllers see, keeping per-IP counters isolated. */
    protected RequestPostProcessor fromClientIp() {
        return request -> {
            request.setRemoteAddr(clientIp);
            return request;
        };
    }

    protected String json(Object body) throws Exception {
        return objectMapper.writeValueAsString(body);
    }

    protected JsonNode body(MvcResult result) throws Exception {
        return objectMapper.readTree(result.getResponse().getContentAsString());
    }

    // ------------------------------------------------------------------ cookies

    /** Value of the cookie set by the response, or null when the response did not set it. */
    protected static String setCookieValue(MockHttpServletResponse response, String name) {
        String header = setCookieHeader(response, name);
        if (header == null) {
            return null;
        }
        int end = header.indexOf(';');
        return header.substring(name.length() + 1, end < 0 ? header.length() : end);
    }

    protected static String setCookieHeader(MockHttpServletResponse response, String name) {
        return response.getHeaders("Set-Cookie").stream()
                .filter(h -> h.startsWith(name + "="))
                .reduce((first, second) -> second)
                .orElse(null);
    }

    // ------------------------------------------------------------------ mail

    /** Sent messages captured from the mocked mail sender, oldest first. */
    protected List<MimeMessage> sentMails(int expectedAtLeast) {
        ArgumentCaptor<MimeMessage> captor = ArgumentCaptor.forClass(MimeMessage.class);
        verify(mailSender, atLeast(expectedAtLeast)).send(captor.capture());
        return captor.getAllValues();
    }

    /** Raw token embedded in the link of the most recently sent email. */
    protected String tokenFromLastMail() throws Exception {
        List<MimeMessage> mails = sentMails(1);
        String text = textOf(mails.get(mails.size() - 1).getContent());
        Matcher matcher = EMAIL_TOKEN.matcher(text);
        if (!matcher.find()) {
            throw new AssertionError("No token link in email: " + text);
        }
        return matcher.group(1);
    }

    protected static String textOf(Object content) throws Exception {
        if (content instanceof String s) {
            return s;
        }
        if (content instanceof Multipart multipart) {
            StringBuilder text = new StringBuilder();
            for (int i = 0; i < multipart.getCount(); i++) {
                BodyPart part = multipart.getBodyPart(i);
                text.append(textOf(part.getContent()));
            }
            return text.toString();
        }
        return "";
    }

    protected static String sha256(String input) {
        try {
            return HexFormat.of().formatHex(
                    MessageDigest.getInstance("SHA-256").digest(input.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }
}
