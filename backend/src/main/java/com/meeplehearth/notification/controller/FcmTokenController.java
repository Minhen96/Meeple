package com.meeplehearth.notification.controller;

import com.meeplehearth.auth.service.SessionService;
import com.meeplehearth.notification.dto.RegisterFcmTokenRequest;
import com.meeplehearth.notification.service.FcmTokenService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

/**
 * Push device registration (docs/GAP_ANALYSIS.md section 6.1, C3). Mapped under
 * {@code /api/v1/users/me} next to the account controller.
 */
@RestController
@RequestMapping("/api/v1/users/me/fcm-tokens")
public class FcmTokenController {

    private final FcmTokenService fcmTokenService;
    private final SessionService sessionService;

    public FcmTokenController(FcmTokenService fcmTokenService, SessionService sessionService) {
        this.fcmTokenService = fcmTokenService;
        this.sessionService = sessionService;
    }

    /**
     * POST /api/v1/users/me/fcm-tokens {token, platform, deviceInfo?} → 204. When the request
     * carries this device's refresh_token cookie, the registration is linked to that session, so
     * signing the session out (DELETE /auth/sessions/{id}, revoke-others) stops its pushes.
     */
    @PostMapping
    public ResponseEntity<Void> register(@AuthenticationPrincipal UserDetails userDetails,
                                         @Valid @RequestBody RegisterFcmTokenRequest request,
                                         HttpServletRequest httpRequest) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        fcmTokenService.register(userId, request, sessionService.currentFamily(userId, httpRequest).orElse(null));
        return ResponseEntity.noContent().build();
    }

    /** DELETE /api/v1/users/me/fcm-tokens/{token} → 204 (also when the token is unknown) */
    @DeleteMapping("/{token}")
    public ResponseEntity<Void> unregister(@AuthenticationPrincipal UserDetails userDetails,
                                           @PathVariable String token) {
        fcmTokenService.unregister(UUID.fromString(userDetails.getUsername()), token);
        return ResponseEntity.noContent().build();
    }
}
