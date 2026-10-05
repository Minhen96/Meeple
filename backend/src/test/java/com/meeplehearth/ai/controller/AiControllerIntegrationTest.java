package com.meeplehearth.ai.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.meeplehearth.support.ai.AiGameIntegrationTestBase;
import com.meeplehearth.support.ai.FakeOpenAi;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;

import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** POST /api/v1/ai/rules end to end: Redis cache + rate limit, pgvector RAG, fake LLM over HTTP. */
class AiControllerIntegrationTest extends AiGameIntegrationTestBase {

    private final ObjectMapper json = new ObjectMapper();

    private ResultActions ask(UUID userId, Object body) throws Exception {
        var request = post("/api/v1/ai/rules").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(body));
        if (userId != null) {
            request.cookie(auth(userId));
        }
        return mvc.perform(request);
    }

    @Test
    void generalModeUsesDescriptionThenServesNormalizedRepeatFromCache() throws Exception {
        UUID user = createUser();
        UUID gameId = game("Dice Racer").description("Roll two dice and race to the finish.").insert();
        OPENAI.onCompletion(body -> "Reach the finish line first.");

        ask(user, Map.of("gameId", gameId, "question", "How do I win?"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.answer").value("Reach the finish line first."))
                .andExpect(jsonPath("$.data.sourceMode").value("general"))
                .andExpect(jsonPath("$.data.cached").value(false));

        List<JsonNode> calls = OPENAI.completionRequests();
        assertThat(calls).hasSize(1);
        assertThat(FakeOpenAi.firstMessage(calls.get(0)))
                .contains("No official rulebook has been uploaded")
                .contains("Roll two dice and race to the finish.");
        assertThat(calls.get(0).path("max_tokens").asInt()).isEqualTo(500);
        assertThat(calls.get(0).path("model").asText()).isNotBlank();
        assertThat(OPENAI.authorizationHeaders()).contains("Bearer test-completion-key");
        assertThat(OPENAI.embeddingInputs()).as("general mode never embeds").isEmpty();

        // Same question modulo case and punctuation → cache hit, no LLM call
        ask(user, Map.of("gameId", gameId, "question", "how do i WIN"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.answer").value("Reach the finish line first."))
                .andExpect(jsonPath("$.data.sourceMode").value("general"))
                .andExpect(jsonPath("$.data.cached").value(true));
        assertThat(OPENAI.completionRequests()).hasSize(1);

        Map<String, Object> logged = jdbc.queryForMap(
                "SELECT user_id, question, answer, source_mode FROM ai_rule_queries WHERE game_id = ?", gameId);
        assertThat(logged).containsEntry("user_id", user)
                .containsEntry("question", "How do I win?")
                .containsEntry("answer", "Reach the finish line first.")
                .containsEntry("source_mode", "general");
    }

    @Test
    void generalModeWithoutDescriptionSaysNoRulebook() throws Exception {
        UUID gameId = game("Bare Game").insert();

        ask(createUser(), Map.of("gameId", gameId, "question", "Setup?"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.sourceMode").value("general"));

        assertThat(FakeOpenAi.firstMessage(OPENAI.completionRequests().get(0)))
                .contains("No rulebook available for this game.");
    }

    @Test
    void rulebookModeRetrievesMostSimilarChunksByVector() throws Exception {
        UUID user = createUser();
        UUID gameId = game("Vector Quest").insert();
        insertChunk(gameId, 0, "Trading rules: swap cards with neighbours.", FakeOpenAi.axis(1));
        insertChunk(gameId, 1, "Scoring rules: each castle scores 3 points.", FakeOpenAi.axis(2));
        for (int i = 2; i < 6; i++) {
            insertChunk(gameId, i, "Filler chunk " + i, FakeOpenAi.axis(10 + i));
        }
        // An identical vector for another game must never leak into this game's context
        UUID otherGame = game("Other Quest").insert();
        insertChunk(otherGame, 0, "Other game scoring.", FakeOpenAi.axis(2));

        OPENAI.onEmbedding(text -> FakeOpenAi.axis(2));
        OPENAI.onCompletion(body -> "Castles score 3 points.");

        ask(user, Map.of("gameId", gameId, "question", "How does scoring work?"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.sourceMode").value("rulebook"))
                .andExpect(jsonPath("$.data.answer").value("Castles score 3 points."))
                .andExpect(jsonPath("$.data.cached").value(false));

        assertThat(OPENAI.embeddingInputs()).containsExactly("How does scoring work?");
        assertThat(OPENAI.authorizationHeaders()).contains("Bearer test-embedding-key");
        String system = FakeOpenAi.firstMessage(OPENAI.completionRequests().get(0));
        String context = system.substring(system.indexOf("RULEBOOK CONTEXT:\n") + "RULEBOOK CONTEXT:\n".length());
        assertThat(context).startsWith("Scoring rules: each castle scores 3 points.");
        assertThat(context.split("\n\n---\n\n")).hasSize(5);
        assertThat(context).doesNotContain("Other game scoring.");
        assertThat(system).contains("Answer ONLY using the rulebook context");

        // Cached answer keeps its rulebook mode
        ask(user, Map.of("gameId", gameId, "question", "How does scoring work"))
                .andExpect(jsonPath("$.data.cached").value(true))
                .andExpect(jsonPath("$.data.sourceMode").value("rulebook"));
    }

    @Test
    void conversationHistoryIsRewrittenIntoStandaloneSearchQueryAndReplayed() throws Exception {
        UUID gameId = game("History Game").insert();
        insertChunk(gameId, 0, "Robber rules.", FakeOpenAi.axis(3));
        OPENAI.onCompletion(body -> body.path("max_tokens").asInt() == 80
                ? "  What happens when the robber moves in History Game?  "
                : "The robber steals one card.");

        ask(createUser(), Map.of("gameId", gameId, "question", "And then what?",
                "conversationHistory", List.of(
                        Map.of("question", "What does a 7 do?", "answer", "The robber moves."),
                        Map.of("question", "Where can it go?", "answer", "Any hex."))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.answer").value("The robber steals one card."));

        List<JsonNode> calls = OPENAI.completionRequests();
        assertThat(calls).hasSize(2);
        assertThat(FakeOpenAi.lastMessage(calls.get(0)))
                .contains("Q: What does a 7 do?\nA: The robber moves.")
                .contains("Follow-up: And then what?");
        assertThat(OPENAI.embeddingInputs()).containsExactly("What happens when the robber moves in History Game?");

        JsonNode messages = calls.get(1).path("messages");
        assertThat(messages).hasSize(6);
        assertThat(messages.get(1).path("role").asText()).isEqualTo("user");
        assertThat(messages.get(1).path("content").asText()).isEqualTo("What does a 7 do?");
        assertThat(messages.get(2).path("role").asText()).isEqualTo("assistant");
        assertThat(messages.get(5).path("content").asText()).isEqualTo("And then what?");
    }

    @Test
    void failedRewriteFallsBackToOriginalQuestion() throws Exception {
        UUID gameId = game("Rewrite Fail").insert();
        insertChunk(gameId, 0, "Some rule.", FakeOpenAi.axis(4));
        OPENAI.onCompletion(body -> {
            if (body.path("max_tokens").asInt() == 80) {
                throw new IllegalStateException("rewrite down");
            }
            return "Fine.";
        });

        ask(createUser(), Map.of("gameId", gameId, "question", "Can I do that?",
                "conversationHistory", List.of(Map.of("question", "q", "answer", "a"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.answer").value("Fine."));

        assertThat(OPENAI.embeddingInputs()).containsExactly("Can I do that?");
    }

    @Test
    void dailyQuestionLimitReturns429() throws Exception {
        UUID user = createUser();
        UUID gameId = game("Limited").insert();
        redis.opsForValue().set("ai:ratelimit:" + user + ":" + LocalDate.now(ZoneOffset.UTC), "20");

        ask(user, Map.of("gameId", gameId, "question", "One more?"))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("AI_RATE_LIMIT"));
        assertThat(OPENAI.completionRequests()).isEmpty();
    }

    @Test
    void eachQuestionConsumesQuotaUntilTheLimit() throws Exception {
        UUID user = createUser();
        UUID gameId = game("Counting").insert();
        String key = "ai:ratelimit:" + user + ":" + LocalDate.now(ZoneOffset.UTC);

        ask(user, Map.of("gameId", gameId, "question", "first")).andExpect(status().isOk());
        ask(user, Map.of("gameId", gameId, "question", "second")).andExpect(status().isOk());

        assertThat(redis.opsForValue().get(key)).isEqualTo("2");
        assertThat(redis.getExpire(key)).isPositive();
    }

    @Test
    void unknownGameIs404() throws Exception {
        ask(createUser(), Map.of("gameId", UUID.randomUUID(), "question", "Hello?"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("GAME_NOT_FOUND"));
    }

    @Test
    void invalidRequestIs400() throws Exception {
        ask(createUser(), Map.of("gameId", UUID.randomUUID(), "question", " "))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }

    @Test
    void anonymousRequestIsRejected() throws Exception {
        ask(null, Map.of("gameId", UUID.randomUUID(), "question", "Hi"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void bearerTokenIsAcceptedToo() throws Exception {
        UUID user = createUser();
        UUID gameId = game("Bearer Game").insert();
        mvc.perform(post("/api/v1/ai/rules").contentType(MediaType.APPLICATION_JSON)
                        .header("Authorization", bearer(user))
                        .content(json.writeValueAsString(Map.of("gameId", gameId, "question", "Hi"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.answer").value("ok"));
    }

    @Test
    void llmFailureIsNotCached() throws Exception {
        UUID user = createUser();
        UUID gameId = game("Broken LLM").insert();
        OPENAI.failCompletions(503);

        ask(user, Map.of("gameId", gameId, "question", "Rules?"))
                .andExpect(status().isInternalServerError());

        OPENAI.reset();
        ask(user, Map.of("gameId", gameId, "question", "Rules?"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.cached").value(false));
    }
}
