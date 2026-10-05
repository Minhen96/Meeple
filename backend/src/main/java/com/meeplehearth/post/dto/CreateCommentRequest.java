package com.meeplehearth.post.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Comment body for create and edit: 1–500 characters (FEATURES_COMPLETE 12.1).
 * {@code @username} mentions notify the mentioned users.
 */
public record CreateCommentRequest(
        @NotBlank @Size(max = 500) String body
) {
}
