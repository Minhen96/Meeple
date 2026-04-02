package com.meeplehearth.ai.controller;

import com.meeplehearth.ai.dto.MyRuleNoteResponse;
import com.meeplehearth.ai.dto.RuleNoteRequest;
import com.meeplehearth.ai.entity.GameRuleNote;
import com.meeplehearth.ai.repository.GameRuleNoteRepository;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/games")
public class RuleNoteController {

    private final GameRuleNoteRepository gameRuleNoteRepository;
    private final GameRepository gameRepository;
    private final UserRepository userRepository;

    public RuleNoteController(GameRuleNoteRepository gameRuleNoteRepository,
                               GameRepository gameRepository,
                               UserRepository userRepository) {
        this.gameRuleNoteRepository = gameRuleNoteRepository;
        this.gameRepository = gameRepository;
        this.userRepository = userRepository;
    }

    // -------------------------------------------------------------------------
    // POST /api/v1/games/{gameId}/rule-notes
    // -------------------------------------------------------------------------

    @PostMapping("/{gameId}/rule-notes")
    public ResponseEntity<MyRuleNoteResponse> submitNote(
            @PathVariable UUID gameId,
            @RequestBody @Valid RuleNoteRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {

        User user = resolveUser(userDetails);
        Optional<GameRuleNote> existing = gameRuleNoteRepository.findByGame_IdAndUser_Id(gameId, user.getId());

        GameRuleNote note;
        if (existing.isPresent()) {
            note = existing.get();
            note.setContent(request.content());
            note.setStatus("pending");
            note.setUpdatedAt(Instant.now());
        } else {
            Game game = gameRepository.findById(gameId)
                    .orElseThrow(() -> ApiException.notFound("GAME_NOT_FOUND", "Game not found"));
            note = new GameRuleNote();
            note.setGame(game);
            note.setUser(user);
            note.setContent(request.content());
        }

        GameRuleNote saved = gameRuleNoteRepository.save(note);
        return ResponseEntity.ok(MyRuleNoteResponse.from(saved));
    }

    // -------------------------------------------------------------------------
    // GET /api/v1/games/{gameId}/rule-notes/my
    // -------------------------------------------------------------------------

    @GetMapping("/{gameId}/rule-notes/my")
    public ResponseEntity<MyRuleNoteResponse> getMyNote(
            @PathVariable UUID gameId,
            @AuthenticationPrincipal UserDetails userDetails) {

        User user = resolveUser(userDetails);
        Optional<GameRuleNote> note = gameRuleNoteRepository.findByGame_IdAndUser_Id(gameId, user.getId());

        if (note.isEmpty()) {
            return ResponseEntity.noContent().build();
        }
        return ResponseEntity.ok(MyRuleNoteResponse.from(note.get()));
    }

    // -------------------------------------------------------------------------
    // DELETE /api/v1/games/{gameId}/rule-notes/my
    // -------------------------------------------------------------------------

    @DeleteMapping("/{gameId}/rule-notes/my")
    public ResponseEntity<Void> deleteMyNote(
            @PathVariable UUID gameId,
            @AuthenticationPrincipal UserDetails userDetails) {

        User user = resolveUser(userDetails);
        Optional<GameRuleNote> noteOpt = gameRuleNoteRepository.findByGame_IdAndUser_Id(gameId, user.getId());

        if (noteOpt.isEmpty()) {
            throw ApiException.notFound("RULE_NOTE_NOT_FOUND", "Rule note not found");
        }

        GameRuleNote note = noteOpt.get();
        if (!"pending".equals(note.getStatus())) {
            throw ApiException.badRequest("RULE_NOTE_NOT_PENDING", "Only pending notes can be deleted");
        }

        gameRuleNoteRepository.delete(note);
        return ResponseEntity.noContent().build();
    }

    // -------------------------------------------------------------------------

    private User resolveUser(UserDetails userDetails) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return userRepository.findById(userId)
                .orElseThrow(() -> ApiException.notFound("USER_NOT_FOUND", "User not found"));
    }
}
