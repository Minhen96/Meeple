package com.meeplehearth.feed.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.meeplehearth.post.dto.PostResponse;

import java.time.Instant;

/**
 * One feed row (docs/GAP_ANALYSIS.md section 6.1): either
 * {@code {kind:"post", createdAt, post}} or {@code {kind:"activity", createdAt, activity}}.
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record FeedItem(String kind, Instant createdAt, PostResponse post, ActivityResponse activity) {

    public static final String POST = "post";
    public static final String ACTIVITY = "activity";

    public static FeedItem post(PostResponse post) {
        return new FeedItem(POST, post.createdAt(), post, null);
    }

    public static FeedItem activity(Instant createdAt, ActivityResponse activity) {
        return new FeedItem(ACTIVITY, createdAt, null, activity);
    }
}
