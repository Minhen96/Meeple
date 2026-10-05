package com.meeplehearth.ai.dto;

import com.meeplehearth.ai.entity.GameRuleNote;
import com.meeplehearth.ai.entity.GameRulebook;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.user.entity.User;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/** Entity → DTO mapping for the admin queue and approved rule notes (reached over HTTP only via buggy paths). */
class AiDtoMappingTest {

    private static Game game() {
        Game game = new Game();
        game.setId(UUID.randomUUID());
        game.setNameEn("Mapped Game");
        return game;
    }

    private static User user(String username) {
        User user = new User();
        user.setId(UUID.randomUUID());
        user.setUsername(username);
        return user;
    }

    @Test
    void queueItemPrefersPdfUrlAndToleratesMissingUploader() {
        Game game = game();
        GameRulebook autoFetched = new GameRulebook();
        autoFetched.setId(UUID.randomUUID());
        autoFetched.setGame(game);
        autoFetched.setSource("onj");
        autoFetched.setPdfUrl("https://cdn.1j1ju.com/a.pdf");
        autoFetched.setPublicUrl("https://r2/ignored.pdf");

        RulebookQueueItem item = RulebookQueueItem.from(autoFetched);
        assertThat(item.id()).isEqualTo(autoFetched.getId());
        assertThat(item.gameId()).isEqualTo(game.getId());
        assertThat(item.gameName()).isEqualTo("Mapped Game");
        assertThat(item.source()).isEqualTo("onj");
        assertThat(item.fileUrl()).isEqualTo("https://cdn.1j1ju.com/a.pdf");
        assertThat(item.uploaderUsername()).isNull();
        assertThat(item.queuePosition()).isNull();
        assertThat(item.createdAt()).isEqualTo(autoFetched.getCreatedAt());

        GameRulebook uploaded = new GameRulebook();
        uploaded.setId(UUID.randomUUID());
        uploaded.setGame(game);
        uploaded.setSource("user");
        uploaded.setPublicUrl("https://r2/rulebooks/x.pdf");
        uploaded.setUploadedBy(user("uploader"));
        uploaded.setQueuePosition(2);

        RulebookQueueItem userItem = RulebookQueueItem.from(uploaded);
        assertThat(userItem.fileUrl()).isEqualTo("https://r2/rulebooks/x.pdf");
        assertThat(userItem.uploaderUsername()).isEqualTo("uploader");
        assertThat(userItem.queuePosition()).isEqualTo(2);
    }

    @Test
    void ruleNoteResponseExposesAuthorAndTimestamps() {
        GameRuleNote note = new GameRuleNote();
        note.setId(UUID.randomUUID());
        note.setGame(game());
        note.setUser(user("author"));
        note.setContent("Ships may not cross land");
        Instant created = Instant.parse("2026-01-02T03:04:05Z");
        note.setCreatedAt(created);

        RuleNoteResponse response = RuleNoteResponse.from(note);
        assertThat(response.id()).isEqualTo(note.getId().toString());
        assertThat(response.content()).isEqualTo("Ships may not cross land");
        assertThat(response.submittedByUsername()).isEqualTo("author");
        assertThat(response.createdAt()).isEqualTo("2026-01-02T03:04:05Z");

        RuleNoteAdminItem adminItem = RuleNoteAdminItem.from(note);
        assertThat(adminItem.gameName()).isEqualTo("Mapped Game");
        assertThat(adminItem.submittedByUsername()).isEqualTo("author");
    }
}
