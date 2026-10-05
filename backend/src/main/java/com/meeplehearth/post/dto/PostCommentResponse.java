package com.meeplehearth.post.dto;

import com.meeplehearth.post.entity.PostComment;

import java.time.Instant;
import java.util.UUID;

public record PostCommentResponse(
        UUID id,
        UUID authorId,
        String authorUsername,
        String authorDisplayName,
        String authorAvatarUrl,
        String body,
        Instant createdAt,
        Instant editedAt
) {
    public static PostCommentResponse from(PostComment comment) {
        return new PostCommentResponse(
                comment.getId(),
                comment.getAuthor().getId(),
                comment.getAuthor().getUsername(),
                comment.getAuthor().getDisplayName(),
                comment.getAuthor().getAvatarUrl(),
                comment.getBody(),
                comment.getCreatedAt(),
                comment.getEditedAt()
        );
    }
}
