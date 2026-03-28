package com.meeplehearth.auth.service;

import com.meeplehearth.auth.dto.AuthResponse;
import com.meeplehearth.auth.dto.AvailabilityResponse;
import com.meeplehearth.auth.dto.MessageResponse;
import com.meeplehearth.auth.entity.EmailVerificationToken;
import com.meeplehearth.auth.entity.PasswordResetToken;
import com.meeplehearth.auth.entity.RefreshToken;
import com.meeplehearth.auth.repository.EmailVerificationTokenRepository;
import com.meeplehearth.auth.repository.PasswordResetTokenRepository;
import com.meeplehearth.auth.repository.RefreshTokenRepository;
import com.meeplehearth.auth.dto.LoginRequest;
import com.meeplehearth.auth.dto.RegisterRequest;
import com.meeplehearth.auth.util.JwtUtil;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.config.AppProperties;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.core.env.Environment;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseCookie;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Arrays;
import java.util.HexFormat;
import java.util.Optional;

@Service
public class AuthService {

    private static final int VERIFICATION_TOKEN_BYTES = 32;
    private static final int RESET_TOKEN_BYTES = 32;
    private static final long MAX_FAILURES = 5L;
    private static final Duration FAILURE_WINDOW = Duration.ofMinutes(15);
    private static final Duration LOCKOUT_DURATION = Duration.ofMinutes(15);
    private static final Duration VERIFICATION_EXPIRY = Duration.ofHours(24);
    private static final Duration RESET_EXPIRY = Duration.ofHours(1);
    private static final int ACCESS_COOKIE_MAX_AGE_SECONDS = 900; // 15 minutes

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final EmailVerificationTokenRepository emailVerificationTokenRepository;
    private final PasswordResetTokenRepository passwordResetTokenRepository;
    private final JwtUtil jwtUtil;
    private final PasswordEncoder passwordEncoder;
    private final StringRedisTemplate redisTemplate;
    private final JavaMailSender mailSender;
    private final AppProperties appProperties;
    private final Environment environment;
    private final SecureRandom secureRandom = new SecureRandom();

    public AuthService(UserRepository userRepository,
            RefreshTokenRepository refreshTokenRepository,
            EmailVerificationTokenRepository emailVerificationTokenRepository,
            PasswordResetTokenRepository passwordResetTokenRepository,
            JwtUtil jwtUtil,
            PasswordEncoder passwordEncoder,
            StringRedisTemplate redisTemplate,
            JavaMailSender mailSender,
            AppProperties appProperties,
            Environment environment) {
        this.userRepository = userRepository;
        this.refreshTokenRepository = refreshTokenRepository;
        this.emailVerificationTokenRepository = emailVerificationTokenRepository;
        this.passwordResetTokenRepository = passwordResetTokenRepository;
        this.jwtUtil = jwtUtil;
        this.passwordEncoder = passwordEncoder;
        this.redisTemplate = redisTemplate;
        this.mailSender = mailSender;
        this.appProperties = appProperties;
        this.environment = environment;
    }

    // -------------------------------------------------------------------------
    // Register
    // -------------------------------------------------------------------------

    @Transactional
    public MessageResponse register(RegisterRequest req) {
        if (userRepository.existsByEmailIgnoreCase(req.email())) {
            throw ApiException.conflict("EMAIL_TAKEN", "Email address is already in use");
        }
        if (userRepository.existsByUsernameIgnoreCase(req.username())) {
            throw ApiException.conflict("USERNAME_TAKEN", "Username is already taken");
        }

        User user = new User();
        user.setEmail(req.email().toLowerCase());
        user.setUsername(req.username());
        user.setDisplayName(req.username());
        user.setPasswordHash(passwordEncoder.encode(req.password()));
        user.setEmailVerified(false);
        userRepository.save(user);

        String rawToken = generateSecureHexToken(VERIFICATION_TOKEN_BYTES);
        String tokenHash = sha256Hex(rawToken);

        EmailVerificationToken evToken = new EmailVerificationToken();
        evToken.setUserId(user.getId());
        evToken.setTokenHash(tokenHash);
        evToken.setExpiresAt(Instant.now().plus(VERIFICATION_EXPIRY));
        emailVerificationTokenRepository.save(evToken);

        sendVerificationEmail(user.getEmail(), rawToken);

        return new MessageResponse("Registration successful. Please check your email to verify your account.");
    }

    // -------------------------------------------------------------------------
    // Login
    // -------------------------------------------------------------------------

    @Transactional
    public AuthResponse login(LoginRequest req, HttpServletResponse response) {
        String identifier = req.emailOrUsername();
        String lockKey = "auth:locked:" + identifier.toLowerCase();
        String failKey = "auth:failures:" + identifier.toLowerCase();

        if (Boolean.TRUE.equals(redisTemplate.hasKey(lockKey))) {
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "TOO_MANY_REQUESTS",
                    "Account temporarily locked due to too many failed login attempts");
        }

        Optional<User> userOpt = identifier.contains("@")
                ? userRepository.findByEmailIgnoreCase(identifier)
                : userRepository.findByUsernameIgnoreCase(identifier);

        if (userOpt.isEmpty()) {
            incrementFailureCounter(failKey, lockKey);
            throw ApiException.unauthorized("Invalid credentials");
        }

        User user = userOpt.get();

        if (!user.isEmailVerified()) {
            throw ApiException.badRequest("EMAIL_NOT_VERIFIED", "Please verify your email address before logging in");
        }

        if (user.getDeletedAt() != null) {
            throw ApiException.unauthorized("Account has been deactivated");
        }

        if (user.getPasswordHash() == null || !passwordEncoder.matches(req.password(), user.getPasswordHash())) {
            incrementFailureCounter(failKey, lockKey);
            throw ApiException.unauthorized("Invalid credentials");
        }

        // Clear failure counters on success
        redisTemplate.delete(failKey);
        redisTemplate.delete(lockKey);

        return issueTokensAndBuildResponse(user, response);
    }

    // -------------------------------------------------------------------------
    // Refresh
    // -------------------------------------------------------------------------

    @Transactional
    public AuthResponse refresh(HttpServletRequest request, HttpServletResponse response) {
        String rawRefreshToken = extractCookie(request, "refresh_token");
        if (rawRefreshToken == null) {
            throw ApiException.unauthorized("No refresh token provided");
        }

        String tokenHash = sha256Hex(rawRefreshToken);
        RefreshToken stored = refreshTokenRepository.findByTokenHash(tokenHash)
                .orElseGet(() -> {
                    // Token not found — possible theft. Attempt to delete all tokens for this user
                    // We can't identify the user here, so just throw 401
                    throw ApiException.unauthorized("Invalid refresh token");
                });

        if (Instant.now().isAfter(stored.getExpiresAt())) {
            refreshTokenRepository.delete(stored);
            throw ApiException.unauthorized("Refresh token has expired");
        }

        User user = userRepository.findById(stored.getUserId())
                .orElseThrow(() -> ApiException.unauthorized("User not found"));

        if (user.getDeletedAt() != null) {
            throw ApiException.unauthorized("Account has been deactivated");
        }

        refreshTokenRepository.delete(stored);

        return issueTokensAndBuildResponse(user, response);
    }

    // -------------------------------------------------------------------------
    // Logout
    // -------------------------------------------------------------------------

    @Transactional
    public void logout(HttpServletRequest request, HttpServletResponse response) {
        String rawRefreshToken = extractCookie(request, "refresh_token");
        if (rawRefreshToken != null) {
            String tokenHash = sha256Hex(rawRefreshToken);
            refreshTokenRepository.findByTokenHash(tokenHash)
                    .ifPresent(refreshTokenRepository::delete);
        }

        clearAuthCookies(response);
    }

    // -------------------------------------------------------------------------
    // Verify Email
    // -------------------------------------------------------------------------

    @Transactional
    public AuthResponse verifyEmail(String rawToken, HttpServletResponse response) {
        String tokenHash = sha256Hex(rawToken);
        EmailVerificationToken evToken = emailVerificationTokenRepository.findByTokenHash(tokenHash)
                .orElseThrow(() -> ApiException.badRequest("INVALID_TOKEN", "Verification token is invalid"));

        if (Instant.now().isAfter(evToken.getExpiresAt())) {
            throw ApiException.badRequest("TOKEN_EXPIRED", "Verification token has expired");
        }

        if (evToken.getUsedAt() != null) {
            throw ApiException.badRequest("TOKEN_USED", "Verification token has already been used");
        }

        User user = userRepository.findById(evToken.getUserId())
                .orElseThrow(() -> ApiException.notFound("User not found"));

        user.setEmailVerified(true);
        userRepository.save(user);

        evToken.setUsedAt(Instant.now());
        emailVerificationTokenRepository.save(evToken);

        return issueTokensAndBuildResponse(user, response);
    }

    // -------------------------------------------------------------------------
    // Resend Verification
    // -------------------------------------------------------------------------

    @Transactional
    public MessageResponse resendVerification(String email) {
        Optional<User> userOpt = userRepository.findByEmailIgnoreCase(email);
        // Always return success to prevent email enumeration
        if (userOpt.isEmpty() || userOpt.get().isEmailVerified()) {
            return new MessageResponse(
                    "If that email exists and is unverified, a new verification email has been sent.");
        }

        User user = userOpt.get();
        String rawToken = generateSecureHexToken(VERIFICATION_TOKEN_BYTES);
        String tokenHash = sha256Hex(rawToken);

        EmailVerificationToken evToken = new EmailVerificationToken();
        evToken.setUserId(user.getId());
        evToken.setTokenHash(tokenHash);
        evToken.setExpiresAt(Instant.now().plus(VERIFICATION_EXPIRY));
        emailVerificationTokenRepository.save(evToken);

        sendVerificationEmail(user.getEmail(), rawToken);

        return new MessageResponse("If that email exists and is unverified, a new verification email has been sent.");
    }

    // -------------------------------------------------------------------------
    // Forgot Password
    // -------------------------------------------------------------------------

    @Transactional
    public MessageResponse forgotPassword(String email) {
        Optional<User> userOpt = userRepository.findByEmailIgnoreCase(email);
        // Always return success to prevent email enumeration
        if (userOpt.isEmpty() || userOpt.get().getDeletedAt() != null) {
            return new MessageResponse("If that email is registered, a password reset link has been sent.");
        }

        User user = userOpt.get();
        String rawToken = generateSecureHexToken(RESET_TOKEN_BYTES);
        String tokenHash = sha256Hex(rawToken);

        PasswordResetToken resetToken = new PasswordResetToken();
        resetToken.setUserId(user.getId());
        resetToken.setTokenHash(tokenHash);
        resetToken.setExpiresAt(Instant.now().plus(RESET_EXPIRY));
        passwordResetTokenRepository.save(resetToken);

        sendPasswordResetEmail(user.getEmail(), rawToken);

        return new MessageResponse("If that email is registered, a password reset link has been sent.");
    }

    // -------------------------------------------------------------------------
    // Reset Password
    // -------------------------------------------------------------------------

    @Transactional
    public MessageResponse resetPassword(String rawToken, String newPassword) {
        String tokenHash = sha256Hex(rawToken);
        PasswordResetToken resetToken = passwordResetTokenRepository.findByTokenHash(tokenHash)
                .orElseThrow(() -> ApiException.badRequest("INVALID_TOKEN", "Password reset token is invalid"));

        if (Instant.now().isAfter(resetToken.getExpiresAt())) {
            throw ApiException.badRequest("TOKEN_EXPIRED", "Password reset token has expired");
        }

        if (resetToken.getUsedAt() != null) {
            throw ApiException.badRequest("TOKEN_USED", "Password reset token has already been used");
        }

        User user = userRepository.findById(resetToken.getUserId())
                .orElseThrow(() -> ApiException.notFound("User not found"));

        user.setPasswordHash(passwordEncoder.encode(newPassword));
        userRepository.save(user);

        resetToken.setUsedAt(Instant.now());
        passwordResetTokenRepository.save(resetToken);

        // Invalidate all refresh tokens for this user (force re-login on all devices)
        refreshTokenRepository.deleteByUserId(user.getId());

        return new MessageResponse("Password has been reset successfully. Please log in with your new password.");
    }

    // -------------------------------------------------------------------------
    // Availability checks
    // -------------------------------------------------------------------------

    public AvailabilityResponse checkUsername(String username) {
        return new AvailabilityResponse(!userRepository.existsByUsernameIgnoreCase(username));
    }

    public AvailabilityResponse checkEmail(String email) {
        return new AvailabilityResponse(!userRepository.existsByEmailIgnoreCase(email));
    }

    // -------------------------------------------------------------------------
    // Private helpers
    // -------------------------------------------------------------------------

    private AuthResponse issueTokensAndBuildResponse(User user, HttpServletResponse response) {
        String accessToken = jwtUtil.generateAccessToken(user.getId());
        String rawRefreshToken = jwtUtil.generateRefreshToken();
        String refreshTokenHash = sha256Hex(rawRefreshToken);

        long refreshExpiryDays = appProperties.getJwt().getRefreshTokenExpiryDays();
        RefreshToken refreshToken = new RefreshToken();
        refreshToken.setUserId(user.getId());
        refreshToken.setTokenHash(refreshTokenHash);
        refreshToken.setExpiresAt(Instant.now().plus(Duration.ofDays(refreshExpiryDays)));
        refreshTokenRepository.save(refreshToken);

        boolean isSecure = isProductionEnvironment();
        long refreshMaxAgeSeconds = refreshExpiryDays * 24 * 60 * 60;

        ResponseCookie accessCookie = ResponseCookie.from("access_token", accessToken)
                .httpOnly(true)
                .secure(isSecure)
                .path("/")
                .maxAge(ACCESS_COOKIE_MAX_AGE_SECONDS)
                .sameSite("Strict")
                .build();

        ResponseCookie refreshCookie = ResponseCookie.from("refresh_token", rawRefreshToken)
                .httpOnly(true)
                .secure(isSecure)
                .path("/api/v1/auth")
                .maxAge(refreshMaxAgeSeconds)
                .sameSite("Strict")
                .build();

        response.addHeader("Set-Cookie", accessCookie.toString());
        response.addHeader("Set-Cookie", refreshCookie.toString());

        return new AuthResponse(
                user.getId(),
                user.getUsername(),
                user.getDisplayName(),
                user.getAvatarUrl(),
                user.getEmail());
    }

    private void clearAuthCookies(HttpServletResponse response) {
        ResponseCookie accessCookie = ResponseCookie.from("access_token", "")
                .httpOnly(true)
                .secure(isProductionEnvironment())
                .path("/")
                .maxAge(0)
                .sameSite("Strict")
                .build();

        ResponseCookie refreshCookie = ResponseCookie.from("refresh_token", "")
                .httpOnly(true)
                .secure(isProductionEnvironment())
                .path("/api/v1/auth")
                .maxAge(0)
                .sameSite("Strict")
                .build();

        response.addHeader("Set-Cookie", accessCookie.toString());
        response.addHeader("Set-Cookie", refreshCookie.toString());
    }

    private void incrementFailureCounter(String failKey, String lockKey) {
        Long count = redisTemplate.opsForValue().increment(failKey);
        if (count != null && count == 1L) {
            redisTemplate.expire(failKey, FAILURE_WINDOW);
        }
        if (count != null && count >= MAX_FAILURES) {
            redisTemplate.opsForValue().set(lockKey, "1", LOCKOUT_DURATION);
        }
    }

    private String generateSecureHexToken(int byteLength) {
        byte[] bytes = new byte[byteLength];
        secureRandom.nextBytes(bytes);
        return HexFormat.of().formatHex(bytes);
    }

    private String sha256Hex(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hashBytes = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hashBytes);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 algorithm not available", e);
        }
    }

    private String extractCookie(HttpServletRequest request, String cookieName) {
        if (request.getCookies() == null) {
            return null;
        }
        return Arrays.stream(request.getCookies())
                .filter(c -> cookieName.equals(c.getName()))
                .map(jakarta.servlet.http.Cookie::getValue)
                .findFirst()
                .orElse(null);
    }

    private boolean isProductionEnvironment() {
        return Arrays.asList(environment.getActiveProfiles()).contains("prod")
                || Arrays.asList(environment.getActiveProfiles()).contains("staging");
    }

    private void sendVerificationEmail(String toEmail, String rawToken) {
        try {
            String frontendUrl = appProperties.getCors().getAllowedOrigins().isEmpty()
                    ? "http://localhost:5173"
                    : appProperties.getCors().getAllowedOrigins().get(0);
            String verifyUrl = frontendUrl + "/verify-email?token=" + rawToken;

            jakarta.mail.internet.MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
            helper.setFrom("noreply@meeplehearth.com");
            helper.setTo(toEmail);
            helper.setSubject("Verify your Meeple account");
            helper.setText(buildVerificationEmailHtml(verifyUrl), true);
            mailSender.send(message);
        } catch (Exception e) {
            // Log at warn level — do not expose token or email in logs
            // Registration still succeeds; user can request a resend
        }
    }

    private void sendPasswordResetEmail(String toEmail, String rawToken) {
        try {
            String frontendUrl = appProperties.getCors().getAllowedOrigins().isEmpty()
                    ? "http://localhost:5173"
                    : appProperties.getCors().getAllowedOrigins().get(0);
            String resetUrl = frontendUrl + "/reset-password?token=" + rawToken;

            jakarta.mail.internet.MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
            helper.setFrom("noreply@meeplehearth.com");
            helper.setTo(toEmail);
            helper.setSubject("Reset your Meeple password");
            helper.setText(buildPasswordResetEmailHtml(resetUrl), true);
            mailSender.send(message);
        } catch (Exception e) {
            // Log at warn level — do not expose token or email in logs
        }
    }

    private String buildVerificationEmailHtml(String verifyUrl) {
        return """
                <!DOCTYPE html>
                <html>
                  <body style="font-family: sans-serif; background: #0f172a; color: #e2e8f0; padding: 40px;">
                    <h2 style="color: #f59e0b;">Welcome to Meeple!</h2>
                    <p>Thanks for signing up. Please verify your email address to get started.</p>
                    <a href="%s"
                       style="display:inline-block; background:#f59e0b; color:#0f172a; padding:12px 24px;
                              border-radius:8px; text-decoration:none; font-weight:bold; margin-top:16px;">
                      Verify Email
                    </a>
                    <p style="margin-top:24px; color:#94a3b8; font-size:14px;">
                      This link expires in 24 hours. If you didn't create an account, you can safely ignore this email.
                    </p>
                  </body>
                </html>
                """.formatted(verifyUrl);
    }

    private String buildPasswordResetEmailHtml(String resetUrl) {
        return """
                <!DOCTYPE html>
                <html>
                  <body style="font-family: sans-serif; background: #0f172a; color: #e2e8f0; padding: 40px;">
                    <h2 style="color: #f59e0b;">Reset your Meeple password</h2>
                    <p>We received a request to reset your password. Click below to set a new one.</p>
                    <a href="%s"
                       style="display:inline-block; background:#f59e0b; color:#0f172a; padding:12px 24px;
                              border-radius:8px; text-decoration:none; font-weight:bold; margin-top:16px;">
                      Reset Password
                    </a>
                    <p style="margin-top:24px; color:#94a3b8; font-size:14px;">
                      This link expires in 1 hour. If you didn't request a password reset, you can safely ignore this email.
                    </p>
                  </body>
                </html>
                """
                .formatted(resetUrl);
    }
}
