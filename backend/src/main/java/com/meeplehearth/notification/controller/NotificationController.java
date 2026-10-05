package com.meeplehearth.notification.controller;

import com.meeplehearth.notification.dto.NotificationPreferenceDto;
import com.meeplehearth.notification.dto.NotificationSettingsDto;
import com.meeplehearth.notification.service.NotificationPreferenceService;
import com.meeplehearth.notification.service.NotificationService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/** Notification centre and preferences (docs/GAP_ANALYSIS.md section 6.1). */
@RestController
@RequestMapping("/api/v1/notifications")
public class NotificationController {

    private final NotificationService notificationService;
    private final NotificationPreferenceService preferenceService;

    public NotificationController(NotificationService notificationService,
                                  NotificationPreferenceService preferenceService) {
        this.notificationService = notificationService;
        this.preferenceService = preferenceService;
    }

    /**
     * GET /api/v1/notifications?cursor=&limit=30 → {@code {items, nextCursor, hasMore}}.
     * Legacy clients sending {@code ?page=} (0-based) and {@code size=} get the old
     * {@code {data, meta}} page shape.
     */
    @GetMapping
    public ResponseEntity<?> getNotifications(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(required = false) String cursor,
            @RequestParam(required = false) Integer limit,
            @RequestParam(required = false) Integer page,
            @RequestParam(required = false) Integer size) {
        UUID userId = userId(userDetails);
        if (page != null && cursor == null && limit == null) {
            return ResponseEntity.ok(notificationService.getNotifications(userId, page, size == null ? 20 : size));
        }
        return ResponseEntity.ok(notificationService.list(userId, cursor, limit));
    }

    /** GET /api/v1/notifications/unread-count → {@code {count}} */
    @GetMapping("/unread-count")
    public ResponseEntity<Map<String, Long>> getUnreadCount(@AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(Map.of("count", notificationService.getUnreadCount(userId(userDetails))));
    }

    /** PUT /api/v1/notifications/read-all */
    @PutMapping("/read-all")
    public ResponseEntity<Void> markAllRead(@AuthenticationPrincipal UserDetails userDetails) {
        notificationService.markAllRead(userId(userDetails));
        return ResponseEntity.noContent().build();
    }

    /** PUT /api/v1/notifications/{id}/read → 204 */
    @PutMapping("/{id}/read")
    public ResponseEntity<Void> markRead(@AuthenticationPrincipal UserDetails userDetails, @PathVariable UUID id) {
        notificationService.markRead(userId(userDetails), id);
        return ResponseEntity.noContent().build();
    }

    /** DELETE /api/v1/notifications/{id} → 204 */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@AuthenticationPrincipal UserDetails userDetails, @PathVariable UUID id) {
        notificationService.delete(userId(userDetails), id);
        return ResponseEntity.noContent().build();
    }

    /** GET /api/v1/notifications/preferences → {@code [{type, inAppEnabled, pushEnabled}]} for every type */
    @GetMapping("/preferences")
    public ResponseEntity<List<NotificationPreferenceDto>> getPreferences(
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(preferenceService.getPreferences(userId(userDetails)));
    }

    /** PUT /api/v1/notifications/preferences with the same array; returns the full list */
    @PutMapping("/preferences")
    public ResponseEntity<List<NotificationPreferenceDto>> updatePreferences(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody List<NotificationPreferenceDto> preferences) {
        return ResponseEntity.ok(preferenceService.updatePreferences(userId(userDetails), preferences));
    }

    /** GET /api/v1/notifications/settings → {@code {quietHoursEnabled, quietHoursStart, quietHoursEnd, timezone}} */
    @GetMapping("/settings")
    public ResponseEntity<NotificationSettingsDto> getSettings(@AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(preferenceService.getSettings(userId(userDetails)));
    }

    /** PUT /api/v1/notifications/settings */
    @PutMapping("/settings")
    public ResponseEntity<NotificationSettingsDto> updateSettings(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody NotificationSettingsDto settings) {
        return ResponseEntity.ok(preferenceService.updateSettings(userId(userDetails), settings));
    }

    private static UUID userId(UserDetails userDetails) {
        return UUID.fromString(userDetails.getUsername());
    }
}
