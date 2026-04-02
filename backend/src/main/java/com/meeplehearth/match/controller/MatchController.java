package com.meeplehearth.match.controller;

import com.meeplehearth.event.dto.EventResponse;
import com.meeplehearth.match.dto.CreateMatchRequestDto;
import com.meeplehearth.match.dto.MatchGroupResponse;
import com.meeplehearth.match.dto.MatchRequestResponse;
import com.meeplehearth.match.service.MatchService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/matches")
public class MatchController {

    private final MatchService matchService;

    public MatchController(MatchService matchService) {
        this.matchService = matchService;
    }

    /** POST /api/v1/matches/requests — create or update a match request */
    @PostMapping("/requests")
    public ResponseEntity<MatchRequestResponse> createRequest(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody CreateMatchRequestDto dto) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(matchService.createRequest(userId, dto));
    }

    /** DELETE /api/v1/matches/requests/{id} — cancel a match request */
    @DeleteMapping("/requests/{id}")
    public ResponseEntity<Void> cancelRequest(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        matchService.cancelRequest(userId, id);
        return ResponseEntity.noContent().build();
    }

    /** GET /api/v1/matches/requests/me — list my active match requests */
    @GetMapping("/requests/me")
    public ResponseEntity<List<MatchRequestResponse>> listMyRequests(
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(matchService.listMyRequests(userId));
    }

    /** GET /api/v1/matches/suggestions — pending match groups I'm part of */
    @GetMapping("/suggestions")
    public ResponseEntity<List<MatchGroupResponse>> getSuggestions(
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(matchService.getSuggestions(userId));
    }

    /** POST /api/v1/matches/{groupId}/accept — accept match, creates event */
    @PostMapping("/{groupId}/accept")
    public ResponseEntity<EventResponse> acceptMatch(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID groupId) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(matchService.acceptMatch(userId, groupId));
    }

    /** POST /api/v1/matches/{groupId}/dismiss — dismiss match for current user */
    @PostMapping("/{groupId}/dismiss")
    public ResponseEntity<Void> dismissMatch(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID groupId) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        matchService.dismissMatch(userId, groupId);
        return ResponseEntity.noContent().build();
    }
}
