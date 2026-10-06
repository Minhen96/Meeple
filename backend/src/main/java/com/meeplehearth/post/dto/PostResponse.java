package com.meeplehearth.post.dto;

import com.meeplehearth.game.dto.GameSummaryResponse;
import com.meeplehearth.post.entity.Post;

import java.time.Instant;
import java.util.List;
import java.util.Set;
import java.util.UUID;

public record PostResponse(
        UUID id,
        AuthorInfo author,
        String caption,
        String location,
        Instant playedAt,
        List<String> imageUrls,
        GameSummaryResponse game,
        UUID eventId,
        List<TaggedUser> taggedUsers,
        int likeCount,
        int commentCount,
        boolean likedByMe,
        boolean isBookmarked,
        Instant createdAt,
        Instant editedAt
) {
    /** {@code deleted}: the author soft-deleted their account; clients render "Deleted User". */
    public record AuthorInfo(UUID id, String username, String displayName, String avatarUrl, boolean deleted) {}
    public record TaggedUser(UUID id, String username, String displayName, String avatarUrl) {}

    /**
     * Without the viewer's bookmark state ({@code isBookmarked=false}). Kept for callers outside
     * the posts package that only know the like state; prefer {@code PostService.loadVisible}.
     */
    public static PostResponse from(Post post, boolean likedByMe, Set<UUID> hiddenUsers) {
        return from(post, likedByMe, false, hiddenUsers);
    }

    public static PostResponse from(Post post, boolean likedByMe, boolean bookmarked) {
        return from(post, likedByMe, bookmarked, Set.of());
    }

    /**
     * @param hiddenUsers users blocked by or blocking the viewer (either way); they are left out
     *                    of {@code taggedUsers}, like deleted accounts
     */
    public static PostResponse from(Post post, boolean likedByMe, boolean bookmarked, Set<UUID> hiddenUsers) {
        AuthorInfo author = new AuthorInfo(
                post.getAuthor().getId(),
                post.getAuthor().getUsername(),
                post.getAuthor().getDisplayName(),
                post.getAuthor().getAvatarUrl(),
                post.getAuthor().getDeletedAt() != null
        );

        List<String> imageUrls = post.getImages().stream()
                .map(img -> img.getUrl())
                .toList();

        GameSummaryResponse game = post.getGame() != null
                ? GameSummaryResponse.from(post.getGame())
                : null;

        List<TaggedUser> taggedUsers = post.getTags().stream()
                .filter(tag -> tag.getUser().getDeletedAt() == null)
                .filter(tag -> !hiddenUsers.contains(tag.getUser().getId()))
                .map(tag -> new TaggedUser(
                        tag.getUser().getId(),
                        tag.getUser().getUsername(),
                        tag.getUser().getDisplayName(),
                        tag.getUser().getAvatarUrl()
                ))
                .toList();

        return new PostResponse(
                post.getId(),
                author,
                post.getCaption(),
                post.getLocation(),
                post.getPlayedAt(),
                imageUrls,
                game,
                post.getEvent() != null ? post.getEvent().getId() : null,
                taggedUsers,
                post.getLikeCount(),
                post.getCommentCount(),
                likedByMe,
                bookmarked,
                post.getCreatedAt(),
                post.getEditedAt()
        );
    }
}
