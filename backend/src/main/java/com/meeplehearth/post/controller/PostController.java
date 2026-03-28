package com.meeplehearth.post.controller;

import com.meeplehearth.common.dto.PageResponse;
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

    /** GET /api/v1/feed?page=0&size=20 — global feed (Phase 1); friends feed in Phase 2 */
    @GetMapping("/feed")
    public ResponseEntity<PageResponse<PostResponse>> getFeed(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(postService.getFeed(userId, page, size));
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

    /** GET /api/v1/posts/{id}/comments?page=0&size=20 */
    @GetMapping("/posts/{id}/comments")
    public ResponseEntity<PageResponse<PostCommentResponse>> getComments(
            @PathVariable UUID id,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(postService.getComments(id, page, size));
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
}
