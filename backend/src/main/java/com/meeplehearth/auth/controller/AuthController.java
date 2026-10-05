package com.meeplehearth.auth.controller;

import com.meeplehearth.auth.dto.AuthResponse;
import com.meeplehearth.auth.dto.AvailabilityResponse;
import com.meeplehearth.auth.dto.LoginRequest;
import com.meeplehearth.auth.dto.MessageResponse;
import com.meeplehearth.auth.dto.ReactivateRequest;
import com.meeplehearth.auth.dto.RegisterRequest;
import com.meeplehearth.auth.dto.SessionResponse;
import com.meeplehearth.auth.service.AuthService;
import com.meeplehearth.auth.service.SessionService;
import com.meeplehearth.user.service.EmailChangeService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    private final AuthService authService;
    private final SessionService sessionService;
    private final EmailChangeService emailChangeService;

    public AuthController(AuthService authService,
                          SessionService sessionService,
                          EmailChangeService emailChangeService) {
        this.authService = authService;
        this.sessionService = sessionService;
        this.emailChangeService = emailChangeService;
    }

    /**
     * POST /api/v1/auth/reactivate
     * Restores an account deleted less than 30 days ago and signs in (same cookies as login).
     * Body: { "emailOrUsername", "password" } or, for Google accounts, { "googleIdToken" }.
     */
    @PostMapping("/reactivate")
    public ResponseEntity<AuthResponse> reactivate(@Valid @RequestBody ReactivateRequest request,
                                                   HttpServletRequest httpRequest,
                                                   HttpServletResponse response) {
        return ResponseEntity.ok(authService.reactivate(request, httpRequest.getRemoteAddr(), response));
    }

    /**
     * POST /api/v1/auth/confirm-email-change
     * Applies a pending email change from the link sent to the new address. Body: { "token" }.
     */
    @PostMapping("/confirm-email-change")
    public ResponseEntity<MessageResponse> confirmEmailChange(@RequestBody Map<String, String> body) {
        return ResponseEntity.ok(emailChangeService.confirm(body.get("token")));
    }

    /** GET /api/v1/auth/sessions — signed-in devices of the current user (authenticated). */
    @GetMapping("/sessions")
    public ResponseEntity<List<SessionResponse>> sessions(@AuthenticationPrincipal UserDetails userDetails,
                                                          HttpServletRequest request) {
        return ResponseEntity.ok(sessionService.listSessions(UUID.fromString(userDetails.getUsername()), request));
    }

    /** DELETE /api/v1/auth/sessions/{id} — signs one other device out (authenticated). */
    @DeleteMapping("/sessions/{id}")
    public ResponseEntity<Void> revokeSession(@AuthenticationPrincipal UserDetails userDetails,
                                              @PathVariable UUID id,
                                              HttpServletRequest request) {
        sessionService.revokeSession(UUID.fromString(userDetails.getUsername()), id, request);
        return ResponseEntity.noContent().build();
    }

    /** POST /api/v1/auth/sessions/revoke-others — signs every other device out (authenticated). */
    @PostMapping("/sessions/revoke-others")
    public ResponseEntity<Map<String, Integer>> revokeOtherSessions(@AuthenticationPrincipal UserDetails userDetails,
                                                                    HttpServletRequest request,
                                                                    HttpServletResponse response) {
        int revoked = sessionService.revokeOtherSessions(UUID.fromString(userDetails.getUsername()), request, response);
        return ResponseEntity.ok(Map.of("revoked", revoked));
    }

    /**
     * POST /api/v1/auth/register
     * Creates a new account and sends a verification email.
     * Returns 201 Created with a message.
     */
    @PostMapping("/register")
    public ResponseEntity<MessageResponse> register(@Valid @RequestBody RegisterRequest request) {
        MessageResponse response = authService.register(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    /**
     * POST /api/v1/auth/login
     * Authenticates the user, sets access_token + refresh_token cookies.
     * Returns 200 with AuthResponse (non-sensitive user info).
     */
    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(@Valid @RequestBody LoginRequest request,
                                              HttpServletRequest httpRequest,
                                              HttpServletResponse response) {
        AuthResponse authResponse = authService.login(request, httpRequest.getRemoteAddr(), response);
        return ResponseEntity.ok(authResponse);
    }

    /**
     * POST /api/v1/auth/logout
     * Deletes the refresh token from DB and clears both cookies.
     */
    @PostMapping("/logout")
    public ResponseEntity<MessageResponse> logout(HttpServletRequest request,
                                                  HttpServletResponse response) {
        authService.logout(request, response);
        return ResponseEntity.ok(new MessageResponse("Logged out successfully"));
    }

    /**
     * POST /api/v1/auth/refresh
     * Uses the refresh_token cookie to issue a new access_token cookie.
     * Returns 200 with AuthResponse.
     */
    @PostMapping("/refresh")
    public ResponseEntity<AuthResponse> refresh(HttpServletRequest request,
                                                HttpServletResponse response) {
        AuthResponse authResponse = authService.refresh(request, response);
        return ResponseEntity.ok(authResponse);
    }

    /**
     * POST /api/v1/auth/verify-email
     * Marks the user's email as verified and issues auth cookies (auto-login).
     * Body: { "token": "<raw hex token>" }
     */
    @PostMapping("/verify-email")
    public ResponseEntity<AuthResponse> verifyEmail(@RequestBody Map<String, String> body,
                                                    HttpServletResponse response) {
        String token = body.get("token");
        if (token == null || token.isBlank()) {
            throw com.meeplehearth.common.exception.ApiException.badRequest("MISSING_TOKEN", "Verification token is required");
        }
        AuthResponse authResponse = authService.verifyEmail(token, response);
        return ResponseEntity.ok(authResponse);
    }

    /**
     * POST /api/v1/auth/resend-verification
     * Resends the email verification link.
     * Body: { "email": "user@example.com" }
     */
    @PostMapping("/resend-verification")
    public ResponseEntity<MessageResponse> resendVerification(@RequestBody Map<String, String> body,
                                                              HttpServletRequest httpRequest) {
        String email = body.get("email");
        if (email == null || email.isBlank()) {
            throw com.meeplehearth.common.exception.ApiException.badRequest("MISSING_EMAIL", "Email is required");
        }
        MessageResponse response = authService.resendVerification(email, httpRequest.getRemoteAddr());
        return ResponseEntity.ok(response);
    }

    /**
     * POST /api/v1/auth/forgot-password
     * Initiates the password reset flow by sending a reset email.
     * Body: { "email": "user@example.com" }
     */
    @PostMapping("/forgot-password")
    public ResponseEntity<MessageResponse> forgotPassword(@RequestBody Map<String, String> body,
                                                          HttpServletRequest httpRequest) {
        String email = body.get("email");
        if (email == null || email.isBlank()) {
            throw com.meeplehearth.common.exception.ApiException.badRequest("MISSING_EMAIL", "Email is required");
        }
        MessageResponse response = authService.forgotPassword(email, httpRequest.getRemoteAddr());
        return ResponseEntity.ok(response);
    }

    /**
     * POST /api/v1/auth/reset-password
     * Completes the password reset using the token from the email link.
     * Body: { "token": "<raw hex token>", "newPassword": "..." }
     */
    @PostMapping("/reset-password")
    public ResponseEntity<MessageResponse> resetPassword(@RequestBody Map<String, String> body) {
        String token = body.get("token");
        String newPassword = body.get("newPassword");
        if (token == null || token.isBlank()) {
            throw com.meeplehearth.common.exception.ApiException.badRequest("MISSING_TOKEN", "Reset token is required");
        }
        if (newPassword == null || newPassword.length() < 8) {
            throw com.meeplehearth.common.exception.ApiException.badRequest("INVALID_PASSWORD",
                    "New password must be at least 8 characters");
        }
        MessageResponse response = authService.resetPassword(token, newPassword);
        return ResponseEntity.ok(response);
    }

    /**
     * POST /api/v1/auth/google
     * Verifies a Google ID token, upserts the user, and sets auth cookies.
     * Body: { "idToken": "<Google credential>" }
     */
    @PostMapping("/google")
    public ResponseEntity<AuthResponse> googleLogin(@RequestBody Map<String, String> body,
                                                    HttpServletResponse response) {
        String idToken = body.get("idToken");
        if (idToken == null || idToken.isBlank()) {
            throw com.meeplehearth.common.exception.ApiException.badRequest("MISSING_TOKEN", "Google ID token is required");
        }
        AuthResponse authResponse = authService.googleLogin(idToken, response);
        return ResponseEntity.ok(authResponse);
    }

    /**
     * GET /api/v1/auth/check-username?username=...
     * Returns { "available": true/false }
     */
    @GetMapping("/check-username")
    public ResponseEntity<AvailabilityResponse> checkUsername(@RequestParam String username) {
        return ResponseEntity.ok(authService.checkUsername(username));
    }

    /**
     * GET /api/v1/auth/check-email?email=...
     * Returns { "available": true/false }
     */
    @GetMapping("/check-email")
    public ResponseEntity<AvailabilityResponse> checkEmail(@RequestParam String email) {
        return ResponseEntity.ok(authService.checkEmail(email));
    }
}
