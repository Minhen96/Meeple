package com.meeplehearth.post.dto;

import com.meeplehearth.game.dto.GameSummaryResponse;
import com.meeplehearth.post.entity.Post;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record PostResponse(
        UUID id,
        AuthorInfo author,
        String caption,
        String location,
        Instant playedAt,
        List<String> imageUrls,
        GameSummaryResponse game,
        List<TaggedUser> taggedUsers,
        int likeCount,
        int commentCount,
        boolean likedByMe,
        Instant createdAt
) {
    public record AuthorInfo(UUID id, String username, String displayName, String avatarUrl) {}
    public record TaggedUser(UUID id, String username, String avatarUrl) {}

    public static PostResponse from(Post post, boolean likedByMe) {
        AuthorInfo author = new AuthorInfo(
                post.getAuthor().getId(),
                post.getAuthor().getUsername(),
                post.getAuthor().getDisplayName(),
                post.getAuthor().getAvatarUrl()
        );

        List<String> imageUrls = post.getImages().stream()
                .map(img -> img.getUrl())
                .toList();

        GameSummaryResponse game = post.getGame() != null
                ? GameSummaryResponse.from(post.getGame())
                : null;

        List<TaggedUser> taggedUsers = post.getTags().stream()
                .map(tag -> new TaggedUser(
                        tag.getUser().getId(),
                        tag.getUser().getUsername(),
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
                taggedUsers,
                post.getLikeCount(),
                post.getCommentCount(),
                likedByMe,
                post.getCreatedAt()
        );
    }
}
