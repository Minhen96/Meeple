package com.meeplehearth.ai.controller;

import com.meeplehearth.ai.dto.RulebookStatusResponse;
import com.meeplehearth.ai.job.RulebookAutoFetchJob;
import com.meeplehearth.support.ai.AiGameIntegrationTestBase;
import com.meeplehearth.support.ai.FakeOpenAi;
import com.meeplehearth.support.ai.TestPdfs;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.ResultActions;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.awaitility.Awaitility.await;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** User rulebook upload / on-demand generate / status endpoints against the real queue and DB. */
class RulebookUserControllerIntegrationTest extends AiGameIntegrationTestBase {

    private static final String CDN_PDF = "https://cdn.1j1ju.com/medias/aa/bb/game-rules.pdf";

    @Autowired private RulebookUserController controller;

    private ResultActions upload(UUID user, UUID gameId, byte[] bytes) throws Exception {
        return mvc.perform(multipart("/api/v1/games/{id}/rulebook", gameId)
                .file(new MockMultipartFile("file", "rules.pdf", "application/pdf", bytes))
                .cookie(auth(user)));
    }

    private ResultActions generate(UUID user, UUID gameId) throws Exception {
        return mvc.perform(post("/api/v1/games/{id}/rulebook/generate", gameId).cookie(auth(user)));
    }

    private ResultActions statusOf(UUID user, UUID gameId) throws Exception {
        return mvc.perform(get("/api/v1/games/{id}/rulebook/status", gameId).cookie(auth(user)));
    }

    // -------------------------------------------------------------------------
    // Upload
    // -------------------------------------------------------------------------

    @Test
    void validUploadsAreQueuedForReviewInOrder() throws Exception {
        UUID first = createUser();
        UUID second = createUser();
        UUID gameId = game("Upload Game").insert();
        OPENAI.onCompletion(body -> "RULEBOOK_MATCH");
        byte[] pdf = TestPdfs.withText("Upload Game rulebook setup turn order scoring");

        upload(first, gameId, pdf)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("pending_review"))
                .andExpect(jsonPath("$.data.queuePosition").value(0))
                .andExpect(jsonPath("$.data.rulebookId").isNotEmpty());
        upload(second, gameId, pdf)
                .andExpect(jsonPath("$.data.queuePosition").value(1));

        ArgumentCaptor<PutObjectRequest> put = ArgumentCaptor.forClass(PutObjectRequest.class);
        verify(s3Client, org.mockito.Mockito.times(2)).putObject(put.capture(), any(RequestBody.class));
        assertThat(put.getValue().key()).startsWith("rulebooks/" + gameId + "/").endsWith(".pdf");
        assertThat(put.getValue().contentType()).isEqualTo("application/pdf");

        Map<String, Object> row = jdbc.queryForMap(
                "SELECT source, status, storage_key, public_url, uploaded_by FROM game_rulebooks "
                        + "WHERE game_id = ? AND queue_position = 0", gameId);
        assertThat(row).containsEntry("source", "user").containsEntry("status", "pending_review")
                .containsEntry("uploaded_by", first);
        assertThat((String) row.get("public_url")).endsWith((String) row.get("storage_key"));

        // The LLM pre-check saw the game name and the PDF text
        String prompt = FakeOpenAi.lastMessage(OPENAI.completionRequests().get(0));
        assertThat(prompt).contains("Board game: \"Upload Game\"").contains("turn order scoring");

        // The uploader sees their own pending submission in the status endpoint
        statusOf(second, gameId)
                .andExpect(jsonPath("$.data.hasRulebook").value(false))
                .andExpect(jsonPath("$.data.isIngesting").value(false))
                .andExpect(jsonPath("$.data.myStatus").value("pending_review"))
                .andExpect(jsonPath("$.data.myQueuePosition").value(1));
    }

    @Test
    void uploadRejectedByLlmPreCheckIsNotStored() throws Exception {
        UUID user = createUser();
        UUID gameId = game("Wrong File Game").insert();
        OPENAI.onCompletion(body -> "RULEBOOK_NO_MATCH");

        upload(user, gameId, TestPdfs.withText("A cookbook about pasta"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_RULEBOOK"));

        verify(s3Client, never()).putObject(any(PutObjectRequest.class), any(RequestBody.class));
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM game_rulebooks WHERE game_id = ?", Integer.class, gameId))
                .isZero();
    }

    @Test
    void nonPdfAndEmptyUploadsAreRejected() throws Exception {
        UUID user = createUser();
        UUID gameId = game("Bad Upload Game").insert();

        upload(user, gameId, "hello, not a pdf".getBytes())
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_PDF"));
        upload(user, gameId, new byte[0])
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("EMPTY_FILE"));
        upload(user, gameId, new byte[]{'%', 'P'})
                .andExpect(jsonPath("$.code").value("INVALID_PDF"));
        assertThat(OPENAI.completionRequests()).isEmpty();
    }

    @Test
    void uploadDailyLimitIs429() throws Exception {
        UUID user = createUser();
        UUID gameId = game("Busy Uploader Game").insert();
        redis.opsForValue().set("rl:rulebook-upload:" + user + ":" + LocalDate.now(ZoneOffset.UTC), "5");

        upload(user, gameId, TestPdfs.withText("rules"))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("RATE_LIMIT_EXCEEDED"));
        assertThat(OPENAI.completionRequests()).isEmpty();
    }

    @Test
    void uploadForApprovedGameIsAlreadyDoneAndUnknownGameIs404() throws Exception {
        UUID user = createUser();
        UUID gameId = game("Done Game").insert();
        insertRulebook(gameId, "onj", "approved", Instant.now());

        upload(user, gameId, TestPdfs.withText("rules"))
                .andExpect(jsonPath("$.data.status").value("already_done"))
                .andExpect(jsonPath("$.data.rulebookId").doesNotExist());
        upload(user, UUID.randomUUID(), TestPdfs.withText("rules"))
                .andExpect(status().isNotFound());
    }

    // -------------------------------------------------------------------------
    // Generate (auto-fetch)
    // -------------------------------------------------------------------------

    @Test
    void generateQueuesAutoFetchedRulebookWhichIsThenIngested() throws Exception {
        UUID user = createUser();
        UUID gameId = game("Fetchable Game").insert();
        when(ruleBookOrgClient.findPdfUrl("Fetchable Game")).thenReturn(Optional.of(CDN_PDF));
        when(pdfDownloader.download(CDN_PDF)).thenReturn(TestPdfs.withText(TestPdfs.words("rule", 400)));

        generate(user, gameId)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("generating"));

        await().atMost(Duration.ofSeconds(30)).untilAsserted(() ->
                statusOf(user, gameId).andExpect(jsonPath("$.data.hasRulebook").value(true)));
        assertThat(jdbc.queryForObject("SELECT source FROM game_rulebooks WHERE game_id = ?", String.class, gameId))
                .isEqualTo("rule_book_org");
        assertThat(chunkCount(gameId)).isEqualTo(2);
        assertThat(redis.opsForValue().get("ai:ratelimit:rulebook-generate:" + user + ":" + LocalDate.now(ZoneOffset.UTC)))
                .isEqualTo("1");
        // How-to-play regeneration is triggered once chunks are stored
        await().atMost(Duration.ofSeconds(30)).until(() ->
                jdbc.queryForObject("SELECT COUNT(*) FROM game_how_to_play WHERE game_id = ?", Integer.class, gameId) == 1);

        generate(user, gameId).andExpect(jsonPath("$.data.status").value("already_done"));
    }

    @Test
    void generateFallsBackToOnjAndReportsNotFound() throws Exception {
        UUID user = createUser();
        UUID nowhere = game("Nowhere Game").insert();
        generate(user, nowhere).andExpect(jsonPath("$.data.status").value("not_found"));

        UUID onj = game("Onj Game").insert();
        when(onjRulebookClient.findPdfUrl("Onj Game")).thenReturn(Optional.of(CDN_PDF));
        generate(user, onj).andExpect(jsonPath("$.data.status").value("generating"));
        assertThat(jdbc.queryForObject("SELECT source FROM game_rulebooks WHERE game_id = ?", String.class, onj))
                .isEqualTo("onj");
        // The downloader mock returns nothing: ingestion marks the row failed
        await().atMost(Duration.ofSeconds(30)).until(() ->
                "failed".equals(jdbc.queryForObject("SELECT status FROM game_rulebooks WHERE game_id = ?", String.class, onj)));
    }

    @Test
    void generateWhileFetchOrIngestionRunsDoesNotUseQuota() throws Exception {
        UUID user = createUser();
        UUID locked = game("Locked Game").insert();
        redis.opsForValue().set(RulebookAutoFetchJob.GAME_LOCK_PREFIX + locked, "1");
        generate(user, locked).andExpect(jsonPath("$.data.status").value("generating"));

        UUID ingesting = game("Ingesting Game").insert();
        insertRulebook(ingesting, "onj", "ingesting", Instant.now());
        generate(user, ingesting).andExpect(jsonPath("$.data.status").value("generating"));

        assertThat(redis.hasKey("ai:ratelimit:rulebook-generate:" + user + ":" + LocalDate.now(ZoneOffset.UTC))).isFalse();
        verify(ruleBookOrgClient, never()).findPdfUrl(anyString());
    }

    @Test
    void generateLimitAndUnknownGame() throws Exception {
        UUID user = createUser();
        UUID gameId = game("Generate Limit Game").insert();
        redis.opsForValue().set("ai:ratelimit:rulebook-generate:" + user + ":" + LocalDate.now(ZoneOffset.UTC), "10");

        generate(user, gameId)
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("RULEBOOK_GENERATE_RATE_LIMIT"));
        generate(user, UUID.randomUUID()).andExpect(status().isNotFound());
    }

    // -------------------------------------------------------------------------
    // Status
    // -------------------------------------------------------------------------

    @Test
    void statusReflectsApprovedIngestingAndRejectedSubmissions() throws Exception {
        UUID user = createUser();
        UUID approved = game("Status Approved").insert();
        insertRulebook(approved, "onj", "approved", Instant.now());
        jdbc.update("INSERT INTO game_how_to_play (game_id, content, source_mode) VALUES (?, '{}'::jsonb, 'rulebook')",
                approved);
        statusOf(user, approved)
                .andExpect(jsonPath("$.data.hasRulebook").value(true))
                .andExpect(jsonPath("$.data.isIngesting").value(false))
                .andExpect(jsonPath("$.data.hasHowToPlay").value(true))
                .andExpect(jsonPath("$.data.myStatus").doesNotExist());

        UUID ingesting = game("Status Ingesting").insert();
        insertRulebook(ingesting, "onj", "ingesting", Instant.now());
        statusOf(user, ingesting).andExpect(jsonPath("$.data.isIngesting").value(true));

        // An 'ingesting' row older than the stale cutoff no longer counts as ingesting
        UUID stale = game("Status Stale").insert();
        insertRulebook(stale, "onj", "ingesting", Instant.now().minus(Duration.ofHours(2)));
        statusOf(user, stale).andExpect(jsonPath("$.data.isIngesting").value(false));

        UUID rejected = game("Status Rejected").insert();
        insertUserRulebook(rejected, user, "rejected", null);
        statusOf(user, rejected)
                .andExpect(jsonPath("$.data.myStatus").value("rejected"))
                .andExpect(jsonPath("$.data.myQueuePosition").doesNotExist());
    }

    @Test
    void anonymousStatusOmitsPersonalSubmission() {
        UUID approved = game("Anon Approved").insert();
        insertRulebook(approved, "onj", "approved", Instant.now());
        UUID ingesting = game("Anon Ingesting").insert();
        insertRulebook(ingesting, "onj", "ingesting", Instant.now());
        UUID none = game("Anon None").insert();

        assertThat(controller.status(approved, null).getBody()).isEqualTo(RulebookStatusResponse.approved(false));
        assertThat(controller.status(ingesting, null).getBody()).isEqualTo(RulebookStatusResponse.ingesting(false));
        assertThat(controller.status(none, null).getBody()).isEqualTo(RulebookStatusResponse.noRulebook(false));
    }

    @Test
    void deletedUserTokenIsRejected() throws Exception {
        UUID user = createUser();
        UUID gameId = game("Ghost Game").insert();
        var token = auth(user);
        jdbc.update("UPDATE users SET deleted_at = now() WHERE id = ?", user);

        mvc.perform(get("/api/v1/games/{id}/rulebook/status", gameId).cookie(token))
                .andExpect(status().isUnauthorized());
    }
}
