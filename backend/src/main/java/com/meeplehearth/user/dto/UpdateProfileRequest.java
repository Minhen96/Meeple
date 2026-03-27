package com.meeplehearth.user.dto;

import jakarta.validation.constraints.Size;

public record UpdateProfileRequest(
        @Size(min = 2, max = 50) String displayName,
        @Size(max = 300) String bio
) {
}
