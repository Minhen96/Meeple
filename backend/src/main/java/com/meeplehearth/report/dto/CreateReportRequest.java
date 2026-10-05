package com.meeplehearth.report.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.util.UUID;

/** {@code POST /api/v1/reports}: {@code targetType} is {@code user} | {@code post} | {@code comment}. */
public record CreateReportRequest(
        @NotBlank @Pattern(regexp = "(?i)user|post|comment", message = "must be user, post or comment")
        String targetType,
        @NotNull UUID targetId,
        @NotBlank @Size(max = 500) String reason
) {
}
