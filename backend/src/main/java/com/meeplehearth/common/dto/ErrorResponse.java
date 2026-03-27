package com.meeplehearth.common.dto;

/**
 * Standard error response.
 * Shape: { "error": "Human-readable message", "code": "SNAKE_CASE_CODE" }
 */
public record ErrorResponse(String error, String code) {
}
