package com.meeplehearth.post.dto;

import com.meeplehearth.post.entity.PostComment;
import com.meeplehearth.user.dto.UserSummary;

import java.time.Instant;
import java.util.UUID;

/**
 * A comment. {@code author} is the shared {@link UserSummary}: {@code deleted=true} with no name
 * or avatar when the author deleted their account, and {@link UserSummary#deletedPlaceholder()}
 * once the hard delete set the author to NULL (FEATURES_COMPLETE section 1.6). The flat
 * {@code author*} fields mirror it for older clients.
 */
public record PostCommentResponse(
        UUID id,
        UserSummary author,
        UUID authorId,
        String authorUsername,
        String authorDisplayName,
        String authorAvatarUrl,
        String body,
        Instant createdAt,
        Instant editedAt
) {
    public static PostCommentResponse from(PostComment comment) {
        UserSummary author = UserSummary.fromNullable(comment.getAuthor());
        return new PostCommentResponse(
                comment.getId(),
                author,
                author.id(),
                author.username(),
                author.displayName(),
                author.avatarUrl(),
                comment.getBody(),
                comment.getCreatedAt(),
                comment.getEditedAt()
        );
    }
}
