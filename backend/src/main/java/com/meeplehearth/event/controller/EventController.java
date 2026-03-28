package com.meeplehearth.event.controller;

import com.meeplehearth.event.dto.CreateEventRequest;
import com.meeplehearth.event.dto.EventResponse;
import com.meeplehearth.event.service.EventService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Pattern;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/events")
@Validated
public class EventController {

    private final EventService eventService;

    public EventController(EventService eventService) {
        this.eventService = eventService;
    }

    /** GET /api/v1/events — upcoming public events */
    @GetMapping
    public ResponseEntity<List<EventResponse>> getEvents(
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(eventService.getUpcomingEvents(userId));
    }

    /** GET /api/v1/events/me — events the current user has accepted */
    @GetMapping("/me")
    public ResponseEntity<List<EventResponse>> getMyEvents(
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(eventService.getMyEvents(userId));
    }

    /** GET /api/v1/events/{id} */
    @GetMapping("/{id}")
    public ResponseEntity<EventResponse> getEvent(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(eventService.getEvent(id, userId));
    }

    /** POST /api/v1/events */
    @PostMapping
    public ResponseEntity<EventResponse> createEvent(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody CreateEventRequest request) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.status(HttpStatus.CREATED).body(eventService.createEvent(userId, request));
    }

    /** PUT /api/v1/events/{id} */
    @PutMapping("/{id}")
    public ResponseEntity<EventResponse> updateEvent(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody CreateEventRequest request) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(eventService.updateEvent(userId, id, request));
    }

    /** DELETE /api/v1/events/{id} */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteEvent(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        eventService.deleteEvent(userId, id);
        return ResponseEntity.noContent().build();
    }

    /** POST /api/v1/events/{id}/rsvp?status=ACCEPTED|DECLINED|INVITED */
    @PostMapping("/{id}/rsvp")
    public ResponseEntity<EventResponse> rsvp(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam @Pattern(regexp = "ACCEPTED|DECLINED|INVITED") String status) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(eventService.rsvp(userId, id, status));
    }

    /** DELETE /api/v1/events/{id}/rsvp — leave event */
    @DeleteMapping("/{id}/rsvp")
    public ResponseEntity<Void> leaveEvent(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        eventService.leaveEvent(userId, id);
        return ResponseEntity.noContent().build();
    }
}
