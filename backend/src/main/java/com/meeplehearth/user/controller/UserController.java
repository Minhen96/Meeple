package com.meeplehearth.user.controller;

import com.meeplehearth.auth.dto.MessageResponse;
import com.meeplehearth.auth.service.AuthService;
import com.meeplehearth.common.dto.PageResponse;
import com.meeplehearth.user.dto.ChangeEmailRequest;
import com.meeplehearth.user.dto.DataExportResponse;
import com.meeplehearth.user.dto.DeleteAccountRequest;
import com.meeplehearth.user.dto.UpdateProfileRequest;
import com.meeplehearth.user.dto.UserProfileResponse;
import com.meeplehearth.user.service.AccountDeletionService;
import com.meeplehearth.user.service.DataExportService;
import com.meeplehearth.user.service.EmailChangeService;
import com.meeplehearth.user.service.UserService;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/users")
public class UserController {

    private final UserService userService;
    private final AccountDeletionService accountDeletionService;
    private final EmailChangeService emailChangeService;
    private final DataExportService dataExportService;
    private final AuthService authService;

    public UserController(UserService userService,
                          AccountDeletionService accountDeletionService,
                          EmailChangeService emailChangeService,
                          DataExportService dataExportService,
                          AuthService authService) {
        this.userService = userService;
        this.accountDeletionService = accountDeletionService;
        this.emailChangeService = emailChangeService;
        this.dataExportService = dataExportService;
        this.authService = authService;
    }

    private static UUID userId(UserDetails userDetails) {
        return UUID.fromString(userDetails.getUsername());
    }

    /** GET /api/v1/users/me — current user's full profile, including account settings */
    @GetMapping("/me")
    public ResponseEntity<UserProfileResponse> getMe(
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(userService.getMe(userId(userDetails)));
    }

    /** PUT /api/v1/users/me — update profile fields, username (once per 30 days), language, time zone */
    @PutMapping("/me")
    public ResponseEntity<UserProfileResponse> updateMe(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody UpdateProfileRequest request) {
        return ResponseEntity.ok(userService.updateMe(userId(userDetails), request));
    }

    /**
     * DELETE /api/v1/users/me — schedule the account for deletion (30-day grace period).
     * Body: {password} or, for accounts without a password, {googleIdToken} or {confirm:"DELETE"}.
     * Ends every session and clears this device's auth cookies.
     */
    @DeleteMapping("/me")
    public ResponseEntity<Void> deleteMe(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody(required = false) DeleteAccountRequest request,
            HttpServletResponse response) {
        accountDeletionService.deleteAccount(userId(userDetails), request);
        authService.clearAuthCookies(response);
        return ResponseEntity.noContent().build();
    }

    /** POST /api/v1/users/me/change-email — emails a confirmation link to the new address */
    @PostMapping("/me/change-email")
    public ResponseEntity<MessageResponse> changeEmail(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody ChangeEmailRequest request) {
        return ResponseEntity.ok(emailChangeService.requestChange(userId(userDetails), request));
    }

    /** GET /api/v1/users/me/export — starts a data export (202); the download link is emailed */
    @GetMapping("/me/export")
    public ResponseEntity<DataExportResponse> export(
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.status(HttpStatus.ACCEPTED).body(dataExportService.requestExport(userId(userDetails)));
    }

    /** GET /api/v1/users/search?q= — search by username or display name */
    @GetMapping("/search")
    public ResponseEntity<PageResponse<UserProfileResponse>> search(
            @RequestParam String q,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(userService.search(q, page, size));
    }

    /** GET /api/v1/users/suggestions — people you may know */
    @GetMapping("/suggestions")
    public ResponseEntity<PageResponse<UserProfileResponse>> getSuggestions(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size) {
        return ResponseEntity.ok(userService.getSuggestions(userId(userDetails), page, size));
    }

    /** GET /api/v1/users/{id} — public profile; 404 if deleted or blocked either way */
    @GetMapping("/{id}")
    public ResponseEntity<UserProfileResponse> getUser(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id) {
        return ResponseEntity.ok(userService.getUser(userId(userDetails), id));
    }
}
