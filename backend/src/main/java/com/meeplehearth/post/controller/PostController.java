package com.meeplehearth.post.controller;

import com.meeplehearth.common.dto.PageResponse;
import com.meeplehearth.feed.dto.CursorPage;
import com.meeplehearth.post.dto.*;
import com.meeplehearth.post.service.PostService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1")
public class PostController {

    private final PostService postService;

    public PostController(PostService postService) {
        this.postService = postService;
    }

    /** GET /api/v1/posts?eventId=&cursor=&limit=20 — "View Memories": posts linked to an event */
    @GetMapping(value = "/posts", params = "eventId")
    public ResponseEntity<CursorPage<PostResponse>> getEventPosts(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam UUID eventId,
            @RequestParam(required = false) String cursor,
            @RequestParam(defaultValue = "20") int limit) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(postService.getEventPosts(userId, eventId, cursor, limit));
    }

    /** GET /api/v1/users/{userId}/tagged-posts?cursor=&limit=20 — posts the user is tagged in */
    @GetMapping("/users/{userId}/tagged-posts")
    public ResponseEntity<CursorPage<PostResponse>> getTaggedPosts(
            @PathVariable UUID userId,
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(required = false) String cursor,
            @RequestParam(defaultValue = "20") int limit) {
        UUID viewerId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(postService.getTaggedPosts(viewerId, userId, cursor, limit));
    }

    /** GET /api/v1/users/me/bookmarks?cursor=&limit=20 — my saved posts, most recently saved first */
    @GetMapping("/users/me/bookmarks")
    public ResponseEntity<CursorPage<PostResponse>> getBookmarks(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(required = false) String cursor,
            @RequestParam(defaultValue = "20") int limit) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(postService.getBookmarks(userId, cursor, limit));
    }

    /** GET /api/v1/users/{userId}/posts?page=0&size=20 */
    @GetMapping("/users/{userId}/posts")
    public ResponseEntity<PageResponse<PostResponse>> getUserPosts(
            @PathVariable UUID userId,
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        UUID currentUserId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(postService.getUserPosts(userId, currentUserId, page, size));
    }

    /** POST /api/v1/posts */
    @PostMapping("/posts")
    public ResponseEntity<PostResponse> createPost(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody CreatePostRequest request) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.status(HttpStatus.CREATED).body(postService.createPost(userId, request));
    }

    /** GET /api/v1/posts/{id} */
    @GetMapping("/posts/{id}")
    public ResponseEntity<PostResponse> getPost(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(postService.getPost(id, userId));
    }

    /** PUT /api/v1/posts/{id} — edit within 48h of creation (author only) */
    @PutMapping("/posts/{id}")
    public ResponseEntity<PostResponse> updatePost(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody UpdatePostRequest request) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(postService.updatePost(userId, id, request));
    }

    /** DELETE /api/v1/posts/{id} */
    @DeleteMapping("/posts/{id}")
    public ResponseEntity<Void> deletePost(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        postService.deletePost(userId, id);
        return ResponseEntity.noContent().build();
    }

    /** POST /api/v1/posts/{id}/like */
    @PostMapping("/posts/{id}/like")
    public ResponseEntity<Void> likePost(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        postService.likePost(userId, id);
        return ResponseEntity.noContent().build();
    }

    /** DELETE /api/v1/posts/{id}/like */
    @DeleteMapping("/posts/{id}/like")
    public ResponseEntity<Void> unlikePost(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        postService.unlikePost(userId, id);
        return ResponseEntity.noContent().build();
    }

    /** POST /api/v1/posts/{id}/bookmark — save (idempotent) */
    @PostMapping("/posts/{id}/bookmark")
    public ResponseEntity<Void> bookmarkPost(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        postService.bookmarkPost(userId, id);
        return ResponseEntity.noContent().build();
    }

    /** DELETE /api/v1/posts/{id}/bookmark — unsave (idempotent) */
    @DeleteMapping("/posts/{id}/bookmark")
    public ResponseEntity<Void> unbookmarkPost(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        postService.unbookmarkPost(userId, id);
        return ResponseEntity.noContent().build();
    }

    /** GET /api/v1/posts/{id}/comments?page=0&size=20 */
    @GetMapping("/posts/{id}/comments")
    public ResponseEntity<PageResponse<PostCommentResponse>> getComments(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(postService.getComments(id, userId, page, size));
    }

    /** POST /api/v1/posts/{id}/comments */
    @PostMapping("/posts/{id}/comments")
    public ResponseEntity<PostCommentResponse> addComment(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody CreateCommentRequest request) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.status(HttpStatus.CREATED).body(postService.addComment(userId, id, request));
    }

    /** PUT /api/v1/posts/{id}/comments/{commentId} — edit within 24h (comment author only) */
    @PutMapping("/posts/{id}/comments/{commentId}")
    public ResponseEntity<PostCommentResponse> updateComment(
            @PathVariable UUID id,
            @PathVariable UUID commentId,
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody CreateCommentRequest request) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(postService.updateComment(userId, id, commentId, request));
    }

    /** DELETE /api/v1/posts/{id}/comments/{commentId} — comment author or post author */
    @DeleteMapping("/posts/{id}/comments/{commentId}")
    public ResponseEntity<Void> deleteComment(
            @PathVariable UUID id,
            @PathVariable UUID commentId,
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        postService.deleteComment(userId, id, commentId);
        return ResponseEntity.noContent().build();
    }
}
