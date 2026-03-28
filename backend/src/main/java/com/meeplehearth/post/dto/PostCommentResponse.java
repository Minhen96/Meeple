package com.meeplehearth.post.dto;

import com.meeplehearth.post.entity.PostComment;

import java.time.Instant;
import java.util.UUID;

public record PostCommentResponse(
        UUID id,
        UUID authorId,
        String authorUsername,
        String authorAvatarUrl,
        String body,
        Instant createdAt
) {
    public static PostCommentResponse from(PostComment comment) {
        return new PostCommentResponse(
                comment.getId(),
                comment.getAuthor().getId(),
                comment.getAuthor().getUsername(),
                comment.getAuthor().getAvatarUrl(),
                comment.getBody(),
                comment.getCreatedAt()
        );
    }
}
