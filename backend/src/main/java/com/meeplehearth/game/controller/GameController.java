package com.meeplehearth.game.controller;

import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.game.dto.*;
import com.meeplehearth.game.job.DataSeedRunner;
import com.meeplehearth.game.service.GameHydrationService;
import com.meeplehearth.game.service.GameService;
import com.meeplehearth.game.service.GameSocialService;
import com.meeplehearth.game.service.LibraryAccessGuard;
import com.meeplehearth.game.service.PlayLogService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;

import java.util.List;
import java.util.UUID;
import java.math.BigDecimal;

@RestController
@RequestMapping("/api/v1")
@Validated
public class GameController {

    private final GameService gameService;
    private final GameHydrationService gameHydrationService;
    private final GameSocialService gameSocialService;
    private final PlayLogService playLogService;
    private final LibraryAccessGuard accessGuard;
    private final DataSeedRunner dataSeedRunner;

    public GameController(GameService gameService,
                          GameHydrationService gameHydrationService,
                          GameSocialService gameSocialService,
                          PlayLogService playLogService,
                          LibraryAccessGuard accessGuard,
                          DataSeedRunner dataSeedRunner) {
        this.gameService = gameService;
        this.gameHydrationService = gameHydrationService;
        this.gameSocialService = gameSocialService;
        this.playLogService = playLogService;
        this.accessGuard = accessGuard;
        this.dataSeedRunner = dataSeedRunner;
    }

    /**
     * POST /api/v1/games/import — admin: re-import the CSV catalog from app.seed.csv-url (SEED_CSV_URL)
     * in the background. 202 when started; 503 SEED_CSV_URL_NOT_CONFIGURED without a URL.
     */
    @PostMapping("/games/import")
    public ResponseEntity<Void> runImport() {
        if (!dataSeedRunner.triggerCatalogImport()) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "SEED_CSV_URL_NOT_CONFIGURED",
                    "SEED_CSV_URL is not configured");
        }
        return ResponseEntity.accepted().build();
    }

    /** POST /api/v1/games/hydrate-images — bulk-fill thumbnail_url for all games missing images */
    @PostMapping("/games/hydrate-images")
    public ResponseEntity<Void> hydrateImages() {
        gameHydrationService.hydrateAllMissingImages();
        return ResponseEntity.ok().build();
    }

    /** GET /api/v1/games — browse catalog; sort=recommended returns personalized results */
    @GetMapping("/games")
    public ResponseEntity<Page<GameSummaryResponse>> browse(
            @RequestParam(required = false) String q,
            @RequestParam(required = false) String genre,
            @RequestParam(required = false) Integer minPlayers,
            @RequestParam(required = false) Integer maxPlayers,
            @RequestParam(required = false) Integer minPlaytime,
            @RequestParam(required = false) Integer maxPlaytime,
            @RequestParam(required = false) BigDecimal minComplexity,
            @RequestParam(required = false) BigDecimal maxComplexity,
            @RequestParam(required = false) BigDecimal minRating,
            @RequestParam(required = false) String sort,
            @PageableDefault(size = 20, sort = "rank") Pageable pageable,
            @AuthenticationPrincipal UserDetails userDetails) {

        if ("recommended".equalsIgnoreCase(sort) && userDetails != null) {
            return ResponseEntity.ok(gameService.getRecommended(userId(userDetails), pageable));
        }

        return ResponseEntity.ok(gameService.browse(q, genre, minPlayers, maxPlayers,
                minPlaytime, maxPlaytime, minComplexity, maxComplexity, minRating, pageable));
    }

    /** GET /api/v1/games/search?q=catan — fuzzy search with CJK translation */
    @GetMapping("/games/search")
    public ResponseEntity<List<GameSearchResult>> search(@RequestParam @NotBlank String q) {
        return ResponseEntity.ok(gameService.search(q));
    }

    /** GET /api/v1/games/{gameId} — catalog detail (cached) plus the viewer's friend data */
    @GetMapping("/games/{gameId}")
    public ResponseEntity<GameDetailResponse> getGame(@PathVariable UUID gameId,
                                                      @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(gameSocialService.withFriendData(gameService.getGame(gameId), userId(userDetails)));
    }

    /** GET /api/v1/games/bgg/{bggId} — fetch from BGG and cache if not found locally */
    @GetMapping("/games/bgg/{bggId}")
    public ResponseEntity<GameDetailResponse> ensureGame(@PathVariable Long bggId) {
        return ResponseEntity.ok(gameService.ensureGame(bggId));
    }

    /** GET /api/v1/users/me/games?filter=all|owned|wishlisted|favorited */
    @GetMapping("/users/me/games")
    public ResponseEntity<List<UserGameResponse>> getCollection(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(defaultValue = "all") String filter) {
        return ResponseEntity.ok(gameService.getCollection(userId(userDetails), filter));
    }

    /** PUT /api/v1/users/me/games/{gameId} — upsert flags + rating + notes; an emptied entry is deleted */
    @PutMapping("/users/me/games/{gameId}")
    public ResponseEntity<UserGameResponse> updateCollection(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID gameId,
            @Valid @RequestBody UserGameRequest request) {
        return ResponseEntity.ok(gameService.updateCollection(userId(userDetails), gameId, request));
    }

    /** DELETE /api/v1/users/me/games/{gameId} — remove from collection entirely */
    @DeleteMapping("/users/me/games/{gameId}")
    public ResponseEntity<Void> removeFromCollection(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID gameId) {
        gameService.removeFromCollection(userId(userDetails), gameId);
        return ResponseEntity.noContent().build();
    }

    /** GET /api/v1/users/me/plays — recent activity across all games (latest 50) */
    @GetMapping("/users/me/plays")
    public ResponseEntity<List<ActivityLogResponse>> getActivity(
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID me = userId(userDetails);
        return ResponseEntity.ok(gameService.getActivity(me, me));
    }

    /** GET /api/v1/users/me/games/{gameId}/plays — play history for this game */
    @GetMapping("/users/me/games/{gameId}/plays")
    public ResponseEntity<List<PlayLogResponse>> getPlays(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID gameId) {
        return ResponseEntity.ok(playLogService.getPlays(userId(userDetails), gameId));
    }

    /** POST /api/v1/users/me/games/{gameId}/plays {playedAt?, notes?, durationMinutes?, playerCount?} */
    @PostMapping("/users/me/games/{gameId}/plays")
    public ResponseEntity<PlayLogResponse> logPlay(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID gameId,
            @Valid @RequestBody(required = false) LogPlayRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(playLogService.logPlay(userId(userDetails), gameId, request));
    }

    /** POST /api/v1/users/me/games/{gameId}/log-play — legacy alias: one play now, returns the entry */
    @PostMapping("/users/me/games/{gameId}/log-play")
    public ResponseEntity<UserGameResponse> logPlayLegacy(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID gameId) {
        return ResponseEntity.ok(playLogService.logPlayLegacy(userId(userDetails), gameId));
    }

    /** DELETE /api/v1/users/me/plays/{playId} — delete one of my plays (play count -1) */
    @DeleteMapping("/users/me/plays/{playId}")
    public ResponseEntity<Void> deletePlay(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID playId) {
        playLogService.deletePlay(userId(userDetails), playId);
        return ResponseEntity.noContent().build();
    }

    /** GET /api/v1/users/{userId}/games — another user's collection; 404 if blocked either way */
    @GetMapping("/users/{userId}/games")
    public ResponseEntity<List<UserGameResponse>> getUserCollection(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID userId,
            @RequestParam(defaultValue = "all") String filter) {
        accessGuard.requireVisible(userId(userDetails), userId);
        return ResponseEntity.ok(gameService.getCollection(userId, filter));
    }

    /** GET /api/v1/users/{userId}/plays — another user's activity; 404 if blocked either way */
    @GetMapping("/users/{userId}/plays")
    public ResponseEntity<List<ActivityLogResponse>> getUserActivity(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID userId) {
        UUID viewer = userId(userDetails);
        accessGuard.requireVisible(viewer, userId);
        return ResponseEntity.ok(gameService.getActivity(userId, viewer));
    }

    private static UUID userId(UserDetails userDetails) {
        return UUID.fromString(userDetails.getUsername());
    }
}
