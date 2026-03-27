package com.meeplehearth.common.dto;

/**
 * Standard success response wrapper.
 * Shape: { "data": T }
 */
public record ApiResponse<T>(T data) {

    public static <T> ApiResponse<T> of(T data) {
        return new ApiResponse<>(data);
    }
}
