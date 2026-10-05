package com.meeplehearth.report.controller;

import com.meeplehearth.report.dto.CreateReportRequest;
import com.meeplehearth.report.service.ReportService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
public class ReportController {

    private final ReportService reportService;

    public ReportController(ReportService reportService) {
        this.reportService = reportService;
    }

    /** POST /api/v1/reports {targetType, targetId, reason} — 201, also when already reported */
    @PostMapping("/api/v1/reports")
    public ResponseEntity<Void> report(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody CreateReportRequest request) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        reportService.report(userId, request);
        return ResponseEntity.status(HttpStatus.CREATED).build();
    }
}
