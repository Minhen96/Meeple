package com.meeplehearth.game.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** Body of {@code POST /users/me/bgg-import}. */
public record BggImportRequest(
        @NotBlank
        @Size(max = 50)
        @Pattern(regexp = "^[\\p{L}\\p{N}_.\\- ]+$", message = "Invalid BoardGameGeek username")
        String bggUsername
) {
}
