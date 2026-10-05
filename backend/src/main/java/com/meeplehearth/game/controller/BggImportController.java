package com.meeplehearth.game.controller;

import com.meeplehearth.game.dto.BggImportRequest;
import com.meeplehearth.game.dto.BggImportStatusResponse;
import com.meeplehearth.game.service.BggCollectionImportService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

/** BoardGameGeek collection import (FEATURES_COMPLETE section 3.2; path per GAP_ANALYSIS C5). */
@RestController
@RequestMapping("/api/v1/users/me/bgg-import")
public class BggImportController {

    private final BggCollectionImportService importService;

    public BggImportController(BggCollectionImportService importService) {
        this.importService = importService;
    }

    /** POST — start an import; 202 {status:"running"}; 503 BGG_API_UNAVAILABLE; 409 BGG_IMPORT_IN_PROGRESS */
    @PostMapping
    public ResponseEntity<BggImportStatusResponse> start(@AuthenticationPrincipal UserDetails userDetails,
                                                         @Valid @RequestBody BggImportRequest request) {
        return ResponseEntity.status(HttpStatus.ACCEPTED)
                .body(importService.start(userId(userDetails), request.bggUsername()));
    }

    /** GET /status — progress, polled by the client every 2s while running */
    @GetMapping("/status")
    public ResponseEntity<BggImportStatusResponse> status(@AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(importService.status(userId(userDetails)));
    }

    private static UUID userId(UserDetails userDetails) {
        return UUID.fromString(userDetails.getUsername());
    }
}
