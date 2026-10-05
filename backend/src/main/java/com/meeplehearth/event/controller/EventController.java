package com.meeplehearth.event.controller;

import com.meeplehearth.event.dto.CreateEventRequest;
import com.meeplehearth.event.dto.EventPageResponse;
import com.meeplehearth.event.dto.EventResponse;
import com.meeplehearth.event.dto.InviteRequest;
import com.meeplehearth.event.dto.UpdateEventRequest;
import com.meeplehearth.event.service.EventService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Pattern;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/events")
@Validated
public class EventController {

    private final EventService eventService;

    public EventController(EventService eventService) {
        this.eventService = eventService;
    }

    /**
     * GET /api/v1/events?scope=upcoming|past|mine&limit=50 (limit capped at 100).
     * upcoming: the caller's circle, soonest first; past: hosted or attended, most recent first;
     * mine: accepted events.
     */
    @GetMapping
    public ResponseEntity<List<EventResponse>> getEvents(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(defaultValue = "upcoming") @Pattern(regexp = "(?i)upcoming|past|mine") String scope,
            @RequestParam(defaultValue = "" + EventService.DEFAULT_LIST_LIMIT) int limit) {
        EventService.ListScope listScope = EventService.ListScope.valueOf(scope.toUpperCase(Locale.ROOT));
        return ResponseEntity.ok(eventService.listEvents(userId(userDetails), listScope, limit));
    }

    /** GET /api/v1/events/me — events the current user has accepted */
    @GetMapping("/me")
    public ResponseEntity<List<EventResponse>> getMyEvents(@AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(eventService.getMyEvents(userId(userDetails)));
    }

    /** GET /api/v1/events/calendar?from=&to= — ISO instants, range at most 62 days */
    @GetMapping("/calendar")
    public ResponseEntity<List<EventResponse>> getCalendar(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to) {
        return ResponseEntity.ok(eventService.getCalendar(userId(userDetails), from, to));
    }

    /** GET /api/v1/events/community?gameId=&cursor=&limit=20 — upcoming public events */
    @GetMapping("/community")
    public ResponseEntity<EventPageResponse> getCommunity(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(required = false) UUID gameId,
            @RequestParam(required = false) String cursor,
            @RequestParam(defaultValue = "" + EventService.DEFAULT_COMMUNITY_LIMIT) int limit) {
        return ResponseEntity.ok(eventService.getCommunityEvents(userId(userDetails), gameId, cursor, limit));
    }

    /** GET /api/v1/events/{id} */
    @GetMapping("/{id}")
    public ResponseEntity<EventResponse> getEvent(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(eventService.getEvent(id, userId(userDetails)));
    }

    /** POST /api/v1/events */
    @PostMapping
    public ResponseEntity<EventResponse> createEvent(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody CreateEventRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(eventService.createEvent(userId(userDetails), request));
    }

    /** PUT /api/v1/events/{id} — partial update, every field optional */
    @PutMapping("/{id}")
    public ResponseEntity<EventResponse> updateEvent(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody UpdateEventRequest request) {
        return ResponseEntity.ok(eventService.updateEvent(userId(userDetails), id, request));
    }

    /** POST /api/v1/events/{id}/cancel — host only */
    @PostMapping("/{id}/cancel")
    public ResponseEntity<Void> cancelEvent(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails) {
        eventService.cancelEvent(userId(userDetails), id);
        return ResponseEntity.noContent().build();
    }

    /** DELETE /api/v1/events/{id} — alias of cancel */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteEvent(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails) {
        eventService.cancelEvent(userId(userDetails), id);
        return ResponseEntity.noContent().build();
    }

    /** POST /api/v1/events/{id}/invites {userIds} — host only, friends only */
    @PostMapping("/{id}/invites")
    public ResponseEntity<EventResponse> invite(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody InviteRequest request) {
        return ResponseEntity.ok(eventService.inviteUsers(userId(userDetails), id, request.userIds()));
    }

    /** POST /api/v1/events/{id}/rsvp?status=ACCEPTED|DECLINED */
    @PostMapping("/{id}/rsvp")
    public ResponseEntity<EventResponse> rsvp(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam @Pattern(regexp = "ACCEPTED|DECLINED") String status) {
        return ResponseEntity.ok(eventService.rsvp(userId(userDetails), id, status));
    }

    /** DELETE /api/v1/events/{id}/rsvp — leave the event (status LEFT) */
    @DeleteMapping("/{id}/rsvp")
    public ResponseEntity<Void> leaveEvent(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails) {
        eventService.leaveEvent(userId(userDetails), id);
        return ResponseEntity.noContent().build();
    }

    /** DELETE /api/v1/events/{id}/participants/{userId} — host kicks a participant */
    @DeleteMapping("/{id}/participants/{participantId}")
    public ResponseEntity<EventResponse> kickParticipant(
            @PathVariable UUID id,
            @PathVariable UUID participantId,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(eventService.kickParticipant(userId(userDetails), id, participantId));
    }

    private static UUID userId(UserDetails userDetails) {
        return UUID.fromString(userDetails.getUsername());
    }
}
