package com.meeplehearth.game.controller;

import com.meeplehearth.game.dto.*;
import com.meeplehearth.game.service.GameDataImportService;
import com.meeplehearth.game.service.GameHydrationService;
import com.meeplehearth.game.service.GameService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
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
    private final GameDataImportService importService;
    private final GameHydrationService gameHydrationService;

    public GameController(GameService gameService, GameDataImportService importService, GameHydrationService gameHydrationService) {
        this.gameService = gameService;
        this.importService = importService;
        this.gameHydrationService = gameHydrationService;
    }

    /** POST /api/v1/games/import — trigger data ingestion from boardgames.csv dataset */
    @PostMapping("/games/import")
    public ResponseEntity<Void> runImport() throws Exception {
        importService.runImport(
                "c:\\Users\\Minhen\\boardgame\\reference\\dataset\\boardgames.csv"
        );
        return ResponseEntity.ok().build();
    }

    /** POST /api/v1/games/hydrate-images — bulk-fill thumbnail_url for all games missing images */
    @PostMapping("/games/hydrate-images")
    public ResponseEntity<Void> hydrateImages() {
        gameHydrationService.hydrateAllMissingImages();
        return ResponseEntity.ok().build();
    }

    /** GET /api/v1/games — browse fully loaded catalog with filters & pagination */
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
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(gameService.browse(q, genre, minPlayers, maxPlayers, minPlaytime, maxPlaytime, minComplexity, maxComplexity, minRating, pageable));
    }

    /** GET /api/v1/games/search?q=catan — search BGG, overlay local cache */
    @GetMapping("/games/search")
    public ResponseEntity<List<GameSearchResult>> search(@RequestParam @NotBlank String q) {
        return ResponseEntity.ok(gameService.search(q));
    }

    /** GET /api/v1/games/{gameId} — get by our UUID (must already be cached) */
    @GetMapping("/games/{gameId}")
    public ResponseEntity<GameDetailResponse> getGame(@PathVariable UUID gameId) {
        return ResponseEntity.ok(gameService.getGame(gameId));
    }

    /** GET /api/v1/games/bgg/{bggId} — fetch from BGG and cache if not found locally */
    @GetMapping("/games/bgg/{bggId}")
    public ResponseEntity<GameDetailResponse> ensureGame(@PathVariable Long bggId) {
        return ResponseEntity.ok(gameService.ensureGame(bggId));
    }

    /** GET /api/v1/users/me/games?filter=owned|wishlisted|favorited|all */
    @GetMapping("/users/me/games")
    public ResponseEntity<List<UserGameResponse>> getCollection(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(defaultValue = "all") String filter) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(gameService.getCollection(userId, filter));
    }

    /** PUT /api/v1/users/me/games/{gameId} — upsert collection flags + rating + notes */
    @PutMapping("/users/me/games/{gameId}")
    public ResponseEntity<UserGameResponse> updateCollection(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID gameId,
            @Valid @RequestBody UserGameRequest request) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(gameService.updateCollection(userId, gameId, request));
    }

    /** GET /api/v1/users/me/plays — recent play activity across all games (latest 50) */
    @GetMapping("/users/me/plays")
    public ResponseEntity<List<ActivityLogResponse>> getActivity(
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(gameService.getActivity(userId));
    }

    /** GET /api/v1/users/me/games/{gameId}/plays — play history for this game */
    @GetMapping("/users/me/games/{gameId}/plays")
    public ResponseEntity<List<PlayLogResponse>> getPlays(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID gameId) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(gameService.getPlays(userId, gameId));
    }

    /** POST /api/v1/users/me/games/{gameId}/log-play — increment play count by 1 */
    @PostMapping("/users/me/games/{gameId}/log-play")
    public ResponseEntity<UserGameResponse> logPlay(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID gameId) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(gameService.logPlay(userId, gameId));
    }

    /** DELETE /api/v1/users/me/games/{gameId} — remove from collection entirely */
    @DeleteMapping("/users/me/games/{gameId}")
    public ResponseEntity<Void> removeFromCollection(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID gameId) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        gameService.removeFromCollection(userId, gameId);
        return ResponseEntity.noContent().build();
    }
}
