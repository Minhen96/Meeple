package com.meeplehearth.game.controller;

import com.meeplehearth.game.dto.CursorPage;
import com.meeplehearth.game.dto.GameFriendResponse;
import com.meeplehearth.game.dto.GameReviewResponse;
import com.meeplehearth.game.dto.UserStatsResponse;
import com.meeplehearth.game.service.GameSocialService;
import com.meeplehearth.game.service.UserStatsService;
import com.meeplehearth.post.dto.PostResponse;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

/** Friend data on game detail and profile stats (docs/GAP_ANALYSIS.md section 6.1, WP4). */
@RestController
@RequestMapping("/api/v1")
public class LibrarySocialController {

    private final GameSocialService gameSocialService;
    private final UserStatsService userStatsService;

    public LibrarySocialController(GameSocialService gameSocialService, UserStatsService userStatsService) {
        this.gameSocialService = gameSocialService;
        this.userStatsService = userStatsService;
    }

    /** GET /api/v1/games/{gameId}/friends — friends who own the game */
    @GetMapping("/games/{gameId}/friends")
    public ResponseEntity<List<GameFriendResponse>> friends(@PathVariable UUID gameId,
                                                            @RequestParam(required = false) Integer limit,
                                                            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(gameSocialService.friendsWhoOwn(gameId, userId(userDetails), limit));
    }

    /** GET /api/v1/games/{gameId}/reviews — friends' ratings and notes */
    @GetMapping("/games/{gameId}/reviews")
    public ResponseEntity<List<GameReviewResponse>> reviews(@PathVariable UUID gameId,
                                                            @RequestParam(required = false) Integer limit,
                                                            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(gameSocialService.friendReviews(gameId, userId(userDetails), limit));
    }

    /** GET /api/v1/games/{gameId}/sessions?cursor=&limit= — posts about the game by me and my friends */
    @GetMapping("/games/{gameId}/sessions")
    public ResponseEntity<CursorPage<PostResponse>> sessions(@PathVariable UUID gameId,
                                                             @RequestParam(required = false) String cursor,
                                                             @RequestParam(required = false) Integer limit,
                                                             @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(gameSocialService.sessions(gameId, userId(userDetails), cursor, limit));
    }

    /** GET /api/v1/users/{userId}/stats — profile stats bento; 404 if blocked either way */
    @GetMapping("/users/{userId}/stats")
    public ResponseEntity<UserStatsResponse> stats(@PathVariable UUID userId,
                                                   @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(userStatsService.getStats(userId(userDetails), userId));
    }

    private static UUID userId(UserDetails userDetails) {
        return UUID.fromString(userDetails.getUsername());
    }
}
