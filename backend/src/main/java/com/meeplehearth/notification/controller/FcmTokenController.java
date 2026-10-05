package com.meeplehearth.notification.controller;

import com.meeplehearth.notification.dto.RegisterFcmTokenRequest;
import com.meeplehearth.notification.service.FcmTokenService;
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

    public FcmTokenController(FcmTokenService fcmTokenService) {
        this.fcmTokenService = fcmTokenService;
    }

    /** POST /api/v1/users/me/fcm-tokens {token, platform, deviceInfo?} → 204 */
    @PostMapping
    public ResponseEntity<Void> register(@AuthenticationPrincipal UserDetails userDetails,
                                         @Valid @RequestBody RegisterFcmTokenRequest request) {
        fcmTokenService.register(UUID.fromString(userDetails.getUsername()), request);
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
