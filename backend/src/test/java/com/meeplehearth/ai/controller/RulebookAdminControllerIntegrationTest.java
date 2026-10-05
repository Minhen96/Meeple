package com.meeplehearth.ai.controller;

import com.meeplehearth.ai.service.RulebookQueueService;
import com.meeplehearth.support.ai.AiGameIntegrationTestBase;
import com.meeplehearth.support.ai.TestPdfs;
import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.ResultActions;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.awaitility.Awaitility.await;
import static org.hamcrest.Matchers.hasItem;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Admin review queue: approve / reject / retry / admin upload, through ingestion to approved chunks. */
class RulebookAdminControllerIntegrationTest extends AiGameIntegrationTestBase {

    @Autowired private RulebookQueueService queueService;

    private ResultActions action(UUID admin, UUID rulebookId, String action) throws Exception {
        return mvc.perform(post("/api/v1/admin/rulebooks/{id}/" + action, rulebookId).cookie(auth(admin)));
    }

    private void awaitStatus(UUID rulebookId, String expected) {
        await().atMost(Duration.ofSeconds(30)).pollInterval(Duration.ofMillis(100))
                .until(() -> expected.equals(rulebookStatus(rulebookId)));
    }

    /** Ingestion triggers how-to-play extraction asynchronously; wait for it before cleanup. */
    private void awaitHowToPlay(UUID gameId) {
        await().atMost(Duration.ofSeconds(30)).until(() ->
                jdbc.queryForObject("SELECT COUNT(*) FROM game_how_to_play WHERE game_id = ?", Integer.class, gameId) == 1);
    }

    @Test
    void adminEndpointsRequireAdminRole() throws Exception {
        UUID user = createUser("USER");
        mvc.perform(get("/api/v1/admin/rulebooks").cookie(auth(user))).andExpect(status().isForbidden());
        mvc.perform(post("/api/v1/admin/rulebooks/{id}/approve", UUID.randomUUID()).cookie(auth(user)))
                .andExpect(status().isForbidden());
        mvc.perform(get("/api/v1/admin/rulebooks")).andExpect(status().isUnauthorized());
    }

    @Test
    void approvingOneSubmissionRejectsTheOthersAndIngestsFromR2() throws Exception {
        UUID admin = createUser("ADMIN");
        UUID uploader = createUser();
        UUID gameId = game("Review Game").insert();
        UUID first = insertUserRulebook(gameId, uploader, "pending_review", 0);
        UUID chosen = insertUserRulebook(gameId, uploader, "pending_review", 1);
        r2Serves(TestPdfs.withText(TestPdfs.words("castle", 800)));

        action(admin, chosen, "approve")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("ingesting"));

        Map<String, Object> other = jdbc.queryForMap(
                "SELECT status, reject_reason, reviewed_by FROM game_rulebooks WHERE id = ?", first);
        assertThat(other).containsEntry("status", "rejected")
                .containsEntry("reject_reason", "Another rulebook was approved for this game")
                .containsEntry("reviewed_by", admin);

        awaitStatus(chosen, "approved");
        ArgumentCaptor<GetObjectRequest> getReq = ArgumentCaptor.forClass(GetObjectRequest.class);
        verify(s3Client).getObject(getReq.capture());
        assertThat(getReq.getValue().key()).isEqualTo("rulebooks/" + gameId + "/" + chosen + ".pdf");

        // 800 words → 3 chunks of up to 375 words with 50-word overlap, embedded through the fake API
        List<Map<String, Object>> chunks = jdbc.queryForList(
                "SELECT chunk_index, token_count, rulebook_id, embedding IS NOT NULL AS has_vec FROM game_rules "
                        + "WHERE game_id = ? ORDER BY chunk_index", gameId);
        assertThat(chunks).hasSize(3);
        assertThat(chunks).extracting(c -> c.get("token_count")).containsExactly(375, 375, 150);
        assertThat(chunks).allSatisfy(c -> {
            assertThat(c.get("rulebook_id")).isEqualTo(chosen);
            assertThat(c.get("has_vec")).isEqualTo(true);
        });
        assertThat(OPENAI.embeddingInputs()).hasSize(3);
        assertThat(OPENAI.embeddingInputs().get(1)).startsWith("castle325 ");
        awaitHowToPlay(gameId);
    }

    @Test
    void approveRequiresPendingReviewAndExistingRulebook() throws Exception {
        UUID admin = createUser("ADMIN");
        UUID gameId = game("Approve Errors").insert();
        UUID approved = insertRulebook(gameId, "onj", "approved", Instant.now());

        action(admin, approved, "approve")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_STATUS"));
        action(admin, approved, "reject")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_STATUS"));
        action(admin, UUID.randomUUID(), "approve")
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("RULEBOOK_NOT_FOUND"));
        action(admin, UUID.randomUUID(), "reject").andExpect(status().isNotFound());
        action(admin, UUID.randomUUID(), "retry").andExpect(status().isNotFound());
    }

    @Test
    void rejectingCompactsTheQueue() throws Exception {
        UUID admin = createUser("ADMIN");
        UUID uploader = createUser();
        UUID gameId = game("Queue Game").insert();
        UUID p0 = insertUserRulebook(gameId, uploader, "pending_review", 0);
        UUID p1 = insertUserRulebook(gameId, uploader, "pending_review", 1);
        UUID p2 = insertUserRulebook(gameId, uploader, "pending_review", 2);

        mvc.perform(post("/api/v1/admin/rulebooks/{id}/reject", p1).cookie(auth(admin))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"reason\":\"Blurry scan\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("rejected"));

        assertThat(jdbc.queryForMap("SELECT status, reject_reason, reviewed_by FROM game_rulebooks WHERE id = ?", p1))
                .containsEntry("status", "rejected").containsEntry("reject_reason", "Blurry scan")
                .containsEntry("reviewed_by", admin);
        assertThat(queuePosition(p0)).isZero();
        assertThat(queuePosition(p2)).isEqualTo(1);

        // Without a body the reason is simply absent
        action(admin, p0, "reject").andExpect(status().isOk());
        assertThat(jdbc.queryForObject("SELECT reject_reason FROM game_rulebooks WHERE id = ?", String.class, p0)).isNull();
        assertThat(queuePosition(p2)).isZero();
    }

    @Test
    void rejectingRulebookWithoutQueuePositionLeavesOthersAlone() throws Exception {
        UUID admin = createUser("ADMIN");
        UUID uploader = createUser();
        UUID gameId = game("No Position Game").insert();
        UUID unpositioned = insertUserRulebook(gameId, uploader, "pending_review", null);
        UUID positioned = insertUserRulebook(gameId, uploader, "pending_review", 3);

        action(admin, unpositioned, "reject").andExpect(status().isOk());
        assertThat(queuePosition(positioned)).isEqualTo(3);
    }

    @Test
    void retryReingestsFailedAndStalledRulebooksOnly() throws Exception {
        UUID admin = createUser("ADMIN");
        UUID gameId = game("Retry Game").insert();
        UUID failed = insertRulebook(gameId, "onj", "failed", Instant.now().minus(Duration.ofDays(1)));
        when(pdfDownloader.download("https://cdn.1j1ju.com/" + failed + ".pdf"))
                .thenReturn(TestPdfs.withText(TestPdfs.words("retry", 50)));

        action(admin, failed, "retry")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("ingesting"));
        awaitStatus(failed, "approved");
        assertThat(jdbc.queryForObject("SELECT reviewed_by FROM game_rulebooks WHERE id = ?", UUID.class, failed))
                .isEqualTo(admin);
        assertThat(chunkCount(gameId)).isEqualTo(1);
        awaitHowToPlay(gameId);

        action(admin, failed, "retry")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_STATUS"));

        UUID other = game("Retry Stale Game").insert();
        UUID fresh = insertRulebook(other, "onj", "ingesting", Instant.now());
        action(admin, fresh, "retry").andExpect(status().isBadRequest());

        UUID stale = insertRulebook(other, "onj", "ingesting", Instant.now().minus(Duration.ofHours(3)));
        jdbc.update("DELETE FROM game_rulebooks WHERE id = ?", fresh);
        // Retry without an acting admin (open admin endpoints in local dev) is allowed too;
        // the downloader returns nothing so the re-run ends in 'failed'
        queueService.retry(stale, null);
        awaitStatus(stale, "failed");
        assertThat(jdbc.queryForObject("SELECT reviewed_at FROM game_rulebooks WHERE id = ?", java.sql.Timestamp.class, stale)
                .toInstant()).isAfter(Instant.now().minus(Duration.ofMinutes(1)));
    }

    @Test
    void adminUploadSupersedesPendingSubmissionsAndIsIngested() throws Exception {
        UUID admin = createUser("ADMIN");
        UUID uploader = createUser();
        UUID gameId = game("Admin Upload Game").insert();
        UUID pending = insertUserRulebook(gameId, uploader, "pending_review", 0);
        byte[] pdf = TestPdfs.withText(TestPdfs.words("admin", 30));
        r2Serves(pdf);

        String body = mvc.perform(multipart("/api/v1/admin/games/{id}/rulebook", gameId)
                        .file(new MockMultipartFile("file", "rules.pdf", "application/pdf", pdf))
                        .cookie(auth(admin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("ingesting"))
                .andReturn().getResponse().getContentAsString();
        UUID rulebookId = UUID.fromString(com.jayway.jsonpath.JsonPath.read(body, "$.data.rulebookId"));

        assertThat(jdbc.queryForMap("SELECT status, reject_reason FROM game_rulebooks WHERE id = ?", pending))
                .containsEntry("status", "rejected")
                .containsEntry("reject_reason", "Admin upload superseded user submissions");
        Map<String, Object> row = jdbc.queryForMap(
                "SELECT source, uploaded_by, reviewed_by FROM game_rulebooks WHERE id = ?", rulebookId);
        assertThat(row).containsEntry("source", "admin").containsEntry("uploaded_by", admin)
                .containsEntry("reviewed_by", admin);
        verify(s3Client).putObject(any(PutObjectRequest.class), any(RequestBody.class));
        assertThat(OPENAI.completionRequests()).as("admin uploads skip the LLM pre-check").noneMatch(
                r -> r.path("max_tokens").asInt() == 10);

        awaitStatus(rulebookId, "approved");
        assertThat(chunkCount(gameId)).isEqualTo(1);
        awaitHowToPlay(gameId);
    }

    @Test
    void adminUploadValidation() throws Exception {
        UUID admin = createUser("ADMIN");
        UUID gameId = game("Admin Upload Errors").insert();

        mvc.perform(multipart("/api/v1/admin/games/{id}/rulebook", UUID.randomUUID())
                        .file(new MockMultipartFile("file", "r.pdf", "application/pdf", TestPdfs.withText("x")))
                        .cookie(auth(admin)))
                .andExpect(status().isNotFound());
        mvc.perform(multipart("/api/v1/admin/games/{id}/rulebook", gameId)
                        .file(new MockMultipartFile("file", "r.pdf", "application/pdf", "nope".getBytes()))
                        .cookie(auth(admin)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_PDF"));
    }

    @Test
    void listQueueShowsPendingSubmissions() throws Exception {
        UUID admin = createUser("ADMIN");
        UUID uploader = createUser();
        UUID gameId = game("Listed Game").insert();
        UUID pending = insertUserRulebook(gameId, uploader, "pending_review", 0);

        mvc.perform(get("/api/v1/admin/rulebooks").param("size", "200").cookie(auth(admin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.content[*].id", hasItem(pending.toString())))
                .andExpect(jsonPath("$.data.content[?(@.id == '" + pending + "')].gameName").value("Listed Game"))
                .andExpect(jsonPath("$.data.content[?(@.id == '" + pending + "')].uploaderUsername")
                        .value(usernameOf(uploader)));
    }

    @Test
    void listQueueForStatusWithoutRowsIsEmpty() throws Exception {
        UUID admin = createUser("ADMIN");
        mvc.perform(get("/api/v1/admin/rulebooks").param("status", "no_such_status").cookie(auth(admin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.content").isEmpty())
                .andExpect(jsonPath("$.data.page.totalElements").value(0));
    }

    private Integer queuePosition(UUID rulebookId) {
        return jdbc.queryForObject("SELECT queue_position FROM game_rulebooks WHERE id = ?", Integer.class, rulebookId);
    }
}
