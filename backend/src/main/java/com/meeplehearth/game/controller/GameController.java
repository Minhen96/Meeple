package com.meeplehearth.game.controller;

import com.meeplehearth.game.dto.*;
import com.meeplehearth.game.service.GameService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1")
@Validated
public class GameController {

    private final GameService gameService;

    public GameController(GameService gameService) {
        this.gameService = gameService;
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
