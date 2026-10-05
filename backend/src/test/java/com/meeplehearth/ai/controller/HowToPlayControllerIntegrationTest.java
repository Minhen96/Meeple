package com.meeplehearth.ai.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.meeplehearth.ai.service.HowToPlayExtractionService;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.support.ai.AiGameIntegrationTestBase;
import com.meeplehearth.support.ai.FakeOpenAi;
import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.ResultActions;

import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.awaitility.Awaitility.await;
import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** How-to-play generate / status / failed flow over HTTP with the real async extraction. */
class HowToPlayControllerIntegrationTest extends AiGameIntegrationTestBase {

    private static final String STRUCTURE_MARKER = "extract a structured 'How to Play' guide";

    @Autowired private HowToPlayExtractionService extractionService;
    @Autowired private GameRepository gameRepository;

    private ResultActions getStatus(UUID user, UUID gameId) throws Exception {
        return mvc.perform(get("/api/v1/games/{id}/how-to-play", gameId).cookie(auth(user)));
    }

    private ResultActions generate(UUID user, UUID gameId) throws Exception {
        return mvc.perform(post("/api/v1/games/{id}/how-to-play/generate", gameId).cookie(auth(user)));
    }

    private void awaitStatus(UUID user, UUID gameId, String expected) {
        await().atMost(Duration.ofSeconds(30)).pollInterval(Duration.ofMillis(100)).untilAsserted(() ->
                getStatus(user, gameId).andExpect(jsonPath("$.data.status").value(expected)));
    }

    private void answerBothPasses(String structure, String faq) {
        OPENAI.onCompletion(body -> FakeOpenAi.lastMessage(body).contains(STRUCTURE_MARKER) ? structure : faq);
    }

    private String rateKey(UUID user) {
        return "ai:ratelimit:how-to-play:" + user + ":" + LocalDate.now(ZoneOffset.UTC);
    }

    @Test
    void notGeneratedUntilRequestedThenGeneratesFromDescription() throws Exception {
        UUID user = createUser();
        UUID gameId = game("Harbour Lords").description("Merchants trade goods in a busy harbour.").insert();
        answerBothPasses("```json\n{\"overview\":\"Trade goods\",\"setup\":\"Place the harbour\"}\n```",
                "{\"faq\":[{\"question\":\"Can I trade twice?\",\"answer\":\"No.\"}],\"tips\":[\"Trade early\"]}");

        getStatus(user, gameId)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("not_generated"));
        assertThat(OPENAI.completionRequests()).as("GET never triggers generation").isEmpty();

        generate(user, gameId)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("generating"))
                .andExpect(jsonPath("$.data.progress").value(0));

        awaitStatus(user, gameId, "ready");
        getStatus(user, gameId)
                .andExpect(jsonPath("$.data.sourceMode").value("general"))
                .andExpect(jsonPath("$.data.disclaimer").value(
                        "Based on AI general knowledge — no rulebook has been uploaded yet."))
                .andExpect(jsonPath("$.data.data.overview").value("Trade goods"))
                .andExpect(jsonPath("$.data.data.setup").value("Place the harbour"))
                .andExpect(jsonPath("$.data.data.faq[0].question").value("Can I trade twice?"))
                .andExpect(jsonPath("$.data.data.tips[0]").value("Trade early"))
                .andExpect(jsonPath("$.data.rulebookUrl").doesNotExist());

        assertThat(OPENAI.completionRequests()).hasSize(2);
        for (JsonNode call : OPENAI.completionRequests()) {
            assertThat(FakeOpenAi.lastMessage(call)).contains("Merchants trade goods in a busy harbour.");
        }
        assertThat(redis.opsForValue().get(rateKey(user))).isEqualTo("1");
        assertThat(extractionService.isGenerating(gameId)).isFalse();
        assertThat(extractionService.getProgress(gameId)).isZero();

        // Already generated: POST returns the content without new LLM calls or quota
        generate(user, gameId)
                .andExpect(jsonPath("$.data.status").value("ready"))
                .andExpect(jsonPath("$.data.data.overview").value("Trade goods"));
        assertThat(OPENAI.completionRequests()).hasSize(2);
        assertThat(redis.opsForValue().get(rateKey(user))).isEqualTo("1");
    }

    @Test
    void rulebookModeUsesChunksInDocumentOrderAndIncludesRulebookUrl() throws Exception {
        UUID user = createUser();
        UUID gameId = game("Chunked Game").insert();
        insertChunk(gameId, 1, "SECOND chunk text", FakeOpenAi.axis(1));
        insertChunk(gameId, 0, "FIRST chunk text", FakeOpenAi.axis(2));
        UUID rulebook = insertRulebook(gameId, "onj", "approved", Instant.now());
        jdbc.update("INSERT INTO game_rule_notes (game_id, user_id, content, status) VALUES (?, ?, ?, 'pending')",
                gameId, user, "Pending note");
        answerBothPasses("{\"overview\":\"From rules\"}", "{\"faq\":[],\"tips\":[]}");

        generate(user, gameId).andExpect(jsonPath("$.data.status").value("generating"));
        awaitStatus(user, gameId, "ready");

        getStatus(user, gameId)
                .andExpect(jsonPath("$.data.sourceMode").value("rulebook"))
                .andExpect(jsonPath("$.data.disclaimer").value("Based on the official rulebook."))
                .andExpect(jsonPath("$.data.rulebookUrl").value("https://cdn.1j1ju.com/" + rulebook + ".pdf"))
                .andExpect(jsonPath("$.data.approvedNotes", hasSize(0)));

        String prompt = FakeOpenAi.lastMessage(OPENAI.completionRequests().get(0));
        assertThat(prompt.indexOf("FIRST chunk text")).isLessThan(prompt.indexOf("SECOND chunk text"));
        assertThat(prompt).contains("FIRST chunk text\n\n---\n\nSECOND chunk text");
    }

    @Test
    void readyGuideIncludesApprovedRuleNotes() throws Exception {
        UUID user = createUser();
        UUID author = createUser();
        UUID gameId = game("Noted Game").insert();
        jdbc.update("INSERT INTO game_how_to_play (game_id, content, source_mode) "
                + "VALUES (?, '{\"overview\":\"x\"}'::jsonb, 'general')", gameId);
        jdbc.update("INSERT INTO game_rule_notes (game_id, user_id, content, status) VALUES (?, ?, ?, 'approved')",
                gameId, author, "House rule: double dice on turn one");

        getStatus(user, gameId)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("ready"))
                .andExpect(jsonPath("$.data.approvedNotes", hasSize(1)))
                .andExpect(jsonPath("$.data.approvedNotes[0].content").value("House rule: double dice on turn one"))
                .andExpect(jsonPath("$.data.approvedNotes[0].submittedByUsername").value(usernameOf(author)));
    }

    @Test
    void failedGenerationIsReportedAndCanBeRetried() throws Exception {
        UUID user = createUser();
        UUID gameId = game("Flaky Game").insert();
        OPENAI.failCompletions(500);

        generate(user, gameId).andExpect(jsonPath("$.data.status").value("generating"));
        awaitStatus(user, gameId, "failed");
        getStatus(user, gameId)
                .andExpect(jsonPath("$.data.errorMessage")
                        .value("We couldn't generate the How to Play guide. Please try again."))
                .andExpect(jsonPath("$.data.data").doesNotExist());
        assertThat(extractionService.isGenerating(gameId)).isFalse();

        OPENAI.reset();
        answerBothPasses("{\"overview\":\"Second try\"}", "{\"tips\":[\"t\"]}");
        generate(user, gameId).andExpect(jsonPath("$.data.status").value("generating"));
        awaitStatus(user, gameId, "ready");
        getStatus(user, gameId).andExpect(jsonPath("$.data.data.overview").value("Second try"));
        assertThat(extractionService.getFailureMessage(gameId)).isEmpty();
    }

    @Test
    void runningExtractionReportsProgressAndDoesNotConsumeQuota() throws Exception {
        UUID user = createUser();
        UUID gameId = game("Busy Game").insert();
        assertThat(extractionService.tryAcquireLock(gameId)).isTrue();
        redis.opsForValue().set("progress:how-to-play:" + gameId, "60");
        try {
            getStatus(user, gameId)
                    .andExpect(jsonPath("$.data.status").value("generating"))
                    .andExpect(jsonPath("$.data.progress").value(60));
            generate(user, gameId)
                    .andExpect(jsonPath("$.data.status").value("generating"))
                    .andExpect(jsonPath("$.data.progress").value(60));

            redis.opsForValue().set("progress:how-to-play:" + gameId, "not-a-number");
            assertThat(extractionService.getProgress(gameId)).isZero();

            // A second extraction while the lock is held is a no-op
            Game game = gameRepository.findById(gameId).orElseThrow();
            extractionService.extract(gameId, game);
            assertThat(OPENAI.completionRequests()).isEmpty();
            assertThat(redis.hasKey(rateKey(user))).isFalse();
        } finally {
            extractionService.releaseLock(gameId);
        }
        assertThat(extractionService.isGenerating(gameId)).isFalse();
    }

    @Test
    void synchronousExtractRunsBothPassesWhenUnlocked() throws Exception {
        UUID user = createUser();
        UUID gameId = game("Sync Game").description("desc").insert();
        answerBothPasses("{\"overview\":\"Sync\"}", "{\"tips\":[\"x\"]}");

        extractionService.extract(gameId, gameRepository.findById(gameId).orElseThrow());

        getStatus(user, gameId)
                .andExpect(jsonPath("$.data.status").value("ready"))
                .andExpect(jsonPath("$.data.data.overview").value("Sync"));
        assertThat(extractionService.isGenerating(gameId)).isFalse();
    }

    @Test
    void dailyLimitReturns429AndReleasesTheLock() throws Exception {
        UUID user = createUser();
        UUID gameId = game("Limited Game").insert();
        redis.opsForValue().set(rateKey(user), "10");

        generate(user, gameId)
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("HOW_TO_PLAY_RATE_LIMIT"));

        assertThat(extractionService.isGenerating(gameId)).isFalse();
        getStatus(user, gameId).andExpect(jsonPath("$.data.status").value("not_generated"));
        assertThat(OPENAI.completionRequests()).isEmpty();
    }

    @Test
    void generateForUnknownGameIs404() throws Exception {
        generate(createUser(), UUID.randomUUID())
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("GAME_NOT_FOUND"));
    }

    @Test
    void truncatedJsonIsRepairedAndUnparseableAnswerKeptRaw() throws Exception {
        UUID user = createUser();
        UUID gameId = game("Messy LLM").insert();
        answerBothPasses("{\"overview\":\"Cut off\",\"phases\":[\"a\",\"b\"", "Sorry, I cannot help with that.");

        generate(user, gameId);
        awaitStatus(user, gameId, "ready");

        getStatus(user, gameId)
                .andExpect(jsonPath("$.data.data.overview").value("Cut off"))
                .andExpect(jsonPath("$.data.data.phases[1]").value("b"))
                .andExpect(jsonPath("$.data.data.raw").value("Sorry, I cannot help with that."));
    }

    @Test
    void anonymousCannotGenerate() throws Exception {
        mvc.perform(post("/api/v1/games/{id}/how-to-play/generate", UUID.randomUUID()))
                .andExpect(status().isUnauthorized());
    }
}
