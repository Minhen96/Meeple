package com.meeplehearth.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

// TODO: Add validation annotations
public record LoginRequest(
        @NotBlank @Email String email,
        @NotBlank String password
) {
}
