package com.meeplehearth.ai.service;

import com.meeplehearth.ai.dto.AiAnswerResponse;
import com.meeplehearth.ai.dto.AiQueryRequest;
import com.meeplehearth.ai.entity.AiRuleQuery;
import com.meeplehearth.ai.entity.RuleChunk;
import com.meeplehearth.ai.repository.AiRuleQueryRepository;
import com.meeplehearth.ai.repository.RuleChunkRepository;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.repository.GameRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Duration;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.*;
import java.util.stream.Collectors;

/**
 * RAG-based AI rules assistant.
 *
 * Pipeline per question:
 *   1. Rate limit (20 questions / user / day via Redis)
 *   2. Normalize + cache lookup (7-day Redis cache keyed by SHA-256 of question)
 *   3. Query rewrite (if conversation history — fuse history+question into standalone query)
 *   4. Context mode: game_rules exist → RAG; else → general knowledge
 *   5. Build prompt (system + context + history + question)
 *   6. LLM completion
 *   7. Cache result
 *   8. Log to ai_rule_queries (for FAQ mining / token savings)
 */
@Service
public class AiService {

    private static final Logger log = LoggerFactory.getLogger(AiService.class);
    private static final int DAILY_QUESTION_LIMIT = 20;
    private static final int RAG_CHUNK_LIMIT = 5;
    private static final long CACHE_TTL_SECONDS = 7 * 24 * 3600; // 7 days

    private final GameRepository gameRepository;
    private final RuleChunkRepository ruleChunkRepository;
    private final EmbeddingService embeddingService;
    private final AiCompletionService completionService;
    private final AiRuleQueryRepository queryLogRepository;
    private final StringRedisTemplate redisTemplate;

    public AiService(GameRepository gameRepository,
                     RuleChunkRepository ruleChunkRepository,
                     EmbeddingService embeddingService,
                     AiCompletionService completionService,
                     AiRuleQueryRepository queryLogRepository,
                     StringRedisTemplate redisTemplate) {
        this.gameRepository = gameRepository;
        this.ruleChunkRepository = ruleChunkRepository;
        this.embeddingService = embeddingService;
        this.completionService = completionService;
        this.queryLogRepository = queryLogRepository;
        this.redisTemplate = redisTemplate;
    }

    // -------------------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------------------

    public AiAnswerResponse ask(UUID userId, AiQueryRequest request) {
        // 1. Rate limit
        checkRateLimit(userId);

        // 2. Cache lookup on the raw question (before rewriting)
        String normalizedQuestion = normalize(request.question());
        String cacheKey = "ai:answer:" + request.gameId() + ":" + sha256(normalizedQuestion);
        String cachedAnswer = redisTemplate.opsForValue().get(cacheKey);

        // Determine source mode for the cache hit (stored alongside in separate key)
        if (cachedAnswer != null) {
            String cachedMode = Optional.ofNullable(
                    redisTemplate.opsForValue().get(cacheKey + ":mode")).orElse("rulebook");
            log.debug("Cache hit for game {} question hash", request.gameId());
            return "rulebook".equals(cachedMode)
                    ? AiAnswerResponse.rulebook(cachedAnswer, true)
                    : AiAnswerResponse.general(cachedAnswer, true);
        }

        // 3. Resolve game
        Game game = gameRepository.findById(request.gameId())
                .orElseThrow(() -> ApiException.notFound("GAME_NOT_FOUND", "Game not found"));

        // 4. Query rewrite — if conversation history present, fuse into standalone query
        String searchQuery = rewriteIfNeeded(request, game.getNameEn());

        // 5. Context mode
        boolean hasRulebook = ruleChunkRepository.existsByGame_Id(game.getId());
        String sourceMode = hasRulebook ? "rulebook" : "general";

        String context;
        if (hasRulebook) {
            float[] embedding = embeddingService.embed(searchQuery);
            String embeddingStr = EmbeddingService.toVectorString(embedding);

            log.debug("Searching for similar chunks for game {} using embedding", game.getNameEn());
            List<RuleChunk> chunks = ruleChunkRepository.findSimilarChunks(
                    game.getId(), embeddingStr, RAG_CHUNK_LIMIT);
            log.info("Found {} similar chunks for RAG search", chunks.size());
            context = chunks.stream()
                    .map(RuleChunk::getChunkText)
                    .collect(Collectors.joining("\n\n---\n\n"));
        } else {
            // Fallback: BGG description
            context = game.getGameDetail() != null && game.getGameDetail().getDescription() != null
                    ? game.getGameDetail().getDescription()
                    : "No rulebook available for this game.";
        }

        // 6. Build messages
        List<Map<String, String>> messages = buildMessages(
                game.getNameEn(), context, request.conversationHistory(), request.question(), hasRulebook);

        // 7. Call LLM
        String answer = completionService.complete(messages, 500, 0.1);

        // 8. Cache result (7 days)
        redisTemplate.opsForValue().set(cacheKey, answer, Duration.ofSeconds(CACHE_TTL_SECONDS));
        redisTemplate.opsForValue().set(cacheKey + ":mode", sourceMode, Duration.ofSeconds(CACHE_TTL_SECONDS));

        // 9. Log to DB (async-ish — fire and ignore failure so it never blocks the response)
        try {
            AiRuleQuery logEntry = new AiRuleQuery();
            logEntry.setUserId(userId);
            logEntry.setGame(game);
            logEntry.setQuestion(request.question());
            logEntry.setAnswer(answer);
            logEntry.setSourceMode(sourceMode);
            queryLogRepository.save(logEntry);
        } catch (Exception e) {
            log.warn("Failed to log AI query for game {}: {}", game.getId(), e.getMessage());
        }

        return "rulebook".equals(sourceMode)
                ? AiAnswerResponse.rulebook(answer, false)
                : AiAnswerResponse.general(answer, false);
    }

    // -------------------------------------------------------------------------
    // Prompt building
    // -------------------------------------------------------------------------

    private List<Map<String, String>> buildMessages(
            String gameName,
            String context,
            List<AiQueryRequest.ConversationTurn> history,
            String question,
            boolean hasRulebook) {

        List<Map<String, String>> messages = new ArrayList<>();

        String systemPrompt = hasRulebook
                ? ("You are a rules assistant for " + gameName + ". "
                   + "Answer ONLY using the rulebook context provided below. "
                   + "If the answer is not in the context, say so clearly. "
                   + "Be concise — 2–4 sentences unless the question requires more detail.\n\n"
                   + "RULEBOOK CONTEXT:\n" + context)
                : ("You are a rules assistant for " + gameName + ". "
                   + "No official rulebook has been uploaded. "
                   + "Answer based on your general knowledge of this game. "
                   + "Be concise and note if you are uncertain.\n\n"
                   + "GAME DESCRIPTION:\n" + context);

        messages.add(Map.of("role", "system", "content", systemPrompt));

        // Conversation history (last 3 turns)
        if (history != null) {
            for (AiQueryRequest.ConversationTurn turn : history) {
                messages.add(Map.of("role", "user", "content", turn.question()));
                messages.add(Map.of("role", "assistant", "content", turn.answer()));
            }
        }

        messages.add(Map.of("role", "user", "content", question));
        return messages;
    }

    /**
     * If conversation history is non-empty, rewrite the question into a
     * standalone search query so pgvector retrieval is not confused by pronouns
     * or references to previous turns.
     */
    private String rewriteIfNeeded(AiQueryRequest request, String gameName) {
        if (request.conversationHistory() == null || request.conversationHistory().isEmpty()) {
            return request.question();
        }
        try {
            String historyText = request.conversationHistory().stream()
                    .map(t -> "Q: " + t.question() + "\nA: " + t.answer())
                    .collect(Collectors.joining("\n"));

            List<Map<String, String>> rewriteMessages = List.of(
                    Map.of("role", "system",
                            "content", "Rewrite the user's follow-up question as a self-contained search "
                                       + "query for a " + gameName + " rulebook. Output only the rewritten query, "
                                       + "no explanation."),
                    Map.of("role", "user",
                            "content", "Chat history:\n" + historyText
                                       + "\n\nFollow-up: " + request.question())
            );
            return completionService.complete(rewriteMessages, 80, 0.0).strip();
        } catch (Exception e) {
            log.warn("Query rewrite failed — using original question: {}", e.getMessage());
            return request.question();
        }
    }

    // -------------------------------------------------------------------------
    // Rate limiting
    // -------------------------------------------------------------------------

    private void checkRateLimit(UUID userId) {
        if (userId == null) return; // anonymous users not rate-limited by user key
        String date = LocalDate.now(ZoneOffset.UTC).toString();
        String key = "ai:ratelimit:" + userId + ":" + date;
        Long count = redisTemplate.opsForValue().increment(key);
        if (count == 1) {
            redisTemplate.expire(key, Duration.ofDays(1));
        }
        if (count != null && count > DAILY_QUESTION_LIMIT) {
            throw ApiException.tooManyRequests("AI_RATE_LIMIT", "Daily question limit reached. Try again tomorrow.");
        }
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private static String normalize(String text) {
        return text.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9 ]", "").trim();
    }

    private static String sha256(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            StringBuilder hex = new StringBuilder();
            for (byte b : hash) hex.append(String.format("%02x", b));
            return hex.toString();
        } catch (Exception e) {
            return Integer.toHexString(input.hashCode()); // fallback
        }
    }
}
