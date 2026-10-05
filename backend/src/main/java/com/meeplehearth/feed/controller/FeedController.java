package com.meeplehearth.feed.controller;

import com.meeplehearth.common.dto.PageResponse;
import com.meeplehearth.feed.dto.CursorPage;
import com.meeplehearth.feed.dto.FeedItem;
import com.meeplehearth.feed.service.FeedService;
import com.meeplehearth.post.dto.PostResponse;
import com.meeplehearth.post.service.PostService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1")
public class FeedController {

    private final FeedService feedService;
    private final PostService postService;

    public FeedController(FeedService feedService, PostService postService) {
        this.feedService = feedService;
        this.postService = postService;
    }

    /**
     * GET /api/v1/feed?cursor=&limit=20 — posts and activity items from friends and me, newest
     * first: {@code {items, nextCursor, hasMore}}.
     */
    @GetMapping("/feed")
    public ResponseEntity<CursorPage<FeedItem>> getFeed(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(required = false) String cursor,
            @RequestParam(defaultValue = "20") int limit) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(feedService.getFeed(userId, cursor, limit));
    }

    /**
     * GET /api/v1/feed?page=0&size=20 — legacy offset feed of posts only, kept for one release so
     * older mobile builds keep working. Selected whenever {@code page} is present.
     */
    @GetMapping(value = "/feed", params = "page")
    public ResponseEntity<PageResponse<PostResponse>> getLegacyFeed(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam int page,
            @RequestParam(defaultValue = "20") int size) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(postService.getFeed(userId, page, size));
    }
}
