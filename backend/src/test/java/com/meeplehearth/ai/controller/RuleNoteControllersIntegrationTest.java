package com.meeplehearth.ai.controller;

import com.meeplehearth.support.ai.AiGameIntegrationTestBase;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;

import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.not;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Community rule notes: user submit / view / delete, admin review queue with notifications. */
class RuleNoteControllersIntegrationTest extends AiGameIntegrationTestBase {

    private ResultActions submit(UUID user, UUID gameId, String content) throws Exception {
        return mvc.perform(post("/api/v1/games/{id}/rule-notes", gameId).cookie(auth(user))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"content\":\"" + content + "\"}"));
    }

    private ResultActions myNote(UUID user, UUID gameId) throws Exception {
        return mvc.perform(get("/api/v1/games/{id}/rule-notes/my", gameId).cookie(auth(user)));
    }

    private UUID noteId(UUID gameId, UUID user) {
        return jdbc.queryForObject("SELECT id FROM game_rule_notes WHERE game_id = ? AND user_id = ?",
                UUID.class, gameId, user);
    }

    @Test
    void submitViewResubmitAndDeleteOwnNote() throws Exception {
        UUID user = createUser();
        UUID gameId = game("Noted Game").insert();

        myNote(user, gameId).andExpect(status().isNoContent());

        submit(user, gameId, "Robber cannot move to the desert")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("pending"))
                .andExpect(jsonPath("$.data.content").value("Robber cannot move to the desert"))
                .andExpect(jsonPath("$.data.id").isNotEmpty());
        UUID id = noteId(gameId, user);

        // A reviewed note goes back to pending when edited
        jdbc.update("UPDATE game_rule_notes SET status = 'rejected', reject_reason = 'unclear' WHERE id = ?", id);
        myNote(user, gameId)
                .andExpect(jsonPath("$.data.status").value("rejected"))
                .andExpect(jsonPath("$.data.rejectReason").value("unclear"));
        submit(user, gameId, "Clearer wording")
                .andExpect(jsonPath("$.data.id").value(id.toString()))
                .andExpect(jsonPath("$.data.status").value("pending"))
                .andExpect(jsonPath("$.data.content").value("Clearer wording"));

        mvc.perform(delete("/api/v1/games/{id}/rule-notes/my", gameId).cookie(auth(user)))
                .andExpect(status().isNoContent());
        myNote(user, gameId).andExpect(status().isNoContent());
        mvc.perform(delete("/api/v1/games/{id}/rule-notes/my", gameId).cookie(auth(user)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("RULE_NOTE_NOT_FOUND"));
    }

    @Test
    void onlyPendingNotesCanBeDeleted() throws Exception {
        UUID user = createUser();
        UUID gameId = game("Approved Note Game").insert();
        submit(user, gameId, "Good rule").andExpect(status().isOk());
        jdbc.update("UPDATE game_rule_notes SET status = 'approved' WHERE game_id = ?", gameId);

        mvc.perform(delete("/api/v1/games/{id}/rule-notes/my", gameId).cookie(auth(user)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("RULE_NOTE_NOT_PENDING"));
    }

    @Test
    void submitValidation() throws Exception {
        UUID user = createUser();
        submit(user, UUID.randomUUID(), "for nothing")
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("GAME_NOT_FOUND"));
        submit(user, game("Validation Note Game").insert(), "  ")
                .andExpect(status().isBadRequest());
    }

    @Test
    void adminApprovesAndRejectsWithNotifications() throws Exception {
        UUID admin = createUser("ADMIN");
        UUID alice = createUser();
        UUID bob = createUser();
        UUID gameId = game("Reviewed Notes Game").insert();
        submit(alice, gameId, "Alice note").andExpect(status().isOk());
        submit(bob, gameId, "Bob note").andExpect(status().isOk());
        UUID aliceNote = noteId(gameId, alice);
        UUID bobNote = noteId(gameId, bob);

        mvc.perform(get("/api/v1/admin/rule-notes").param("size", "500").cookie(auth(admin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.content[*].id", hasItem(aliceNote.toString())))
                .andExpect(jsonPath("$.data.content[?(@.id == '" + aliceNote + "')].gameName").value("Reviewed Notes Game"))
                .andExpect(jsonPath("$.data.content[?(@.id == '" + aliceNote + "')].submittedByUsername")
                        .value(usernameOf(alice)));

        mvc.perform(post("/api/v1/admin/rule-notes/{id}/approve", aliceNote).cookie(auth(admin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("approved"));
        mvc.perform(post("/api/v1/admin/rule-notes/{id}/reject", bobNote).cookie(auth(admin))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"reason\":\"Not a rule\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("rejected"));

        assertThat(jdbc.queryForMap("SELECT status, reviewed_by FROM game_rule_notes WHERE id = ?", aliceNote))
                .containsEntry("status", "approved").containsEntry("reviewed_by", admin);
        assertThat(jdbc.queryForMap("SELECT status, reject_reason FROM game_rule_notes WHERE id = ?", bobNote))
                .containsEntry("status", "rejected").containsEntry("reject_reason", "Not a rule");

        Map<String, Object> aliceNotif = jdbc.queryForMap(
                "SELECT type, actor_id, reference_id, reference_type FROM notifications WHERE recipient_id = ?", alice);
        assertThat(aliceNotif).containsEntry("type", "RULE_NOTE_APPROVED").containsEntry("actor_id", admin)
                .containsEntry("reference_id", aliceNote).containsEntry("reference_type", "RULE_NOTE");
        assertThat(jdbc.queryForObject("SELECT type FROM notifications WHERE recipient_id = ?", String.class, bob))
                .isEqualTo("RULE_NOTE_REJECTED");

        // Reviewed notes leave the pending queue
        mvc.perform(get("/api/v1/admin/rule-notes").param("size", "500").cookie(auth(admin)))
                .andExpect(jsonPath("$.data.content[*].id", not(hasItem(aliceNote.toString()))));

        // Rejection without a body
        submit(bob, gameId, "Bob again").andExpect(status().isOk());
        mvc.perform(post("/api/v1/admin/rule-notes/{id}/reject", bobNote).cookie(auth(admin)))
                .andExpect(status().isOk());
        assertThat(jdbc.queryForObject("SELECT reject_reason FROM game_rule_notes WHERE id = ?", String.class, bobNote))
                .isNull();
    }

    @Test
    void adminReviewOfUnknownNoteIs404AndUsersAreForbidden() throws Exception {
        UUID admin = createUser("ADMIN");
        UUID user = createUser();
        mvc.perform(post("/api/v1/admin/rule-notes/{id}/approve", UUID.randomUUID()).cookie(auth(admin)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("RULE_NOTE_NOT_FOUND"));
        mvc.perform(post("/api/v1/admin/rule-notes/{id}/reject", UUID.randomUUID()).cookie(auth(admin)))
                .andExpect(status().isNotFound());
        mvc.perform(get("/api/v1/admin/rule-notes").cookie(auth(user)))
                .andExpect(status().isForbidden());
    }
}
