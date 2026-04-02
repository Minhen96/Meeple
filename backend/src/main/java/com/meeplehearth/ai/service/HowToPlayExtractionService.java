package com.meeplehearth.ai.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.meeplehearth.ai.entity.GameHowToPlay;
import com.meeplehearth.ai.entity.RuleChunk;
import com.meeplehearth.ai.repository.GameHowToPlayRepository;
import com.meeplehearth.ai.repository.RuleChunkRepository;
import com.meeplehearth.game.entity.Game;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Two-pass GPT extraction of structured How-to-Play content from rule chunks.
 *
 * Pass 1 — structure: extracts setup, gameplay, components, win condition, etc. as JSON.
 * Pass 2 — FAQ + tips: generates 3–5 beginner Q&A pairs and practical tips.
 *
 * Progress is tracked in Redis (0–100) and pushed over WebSocket to
 * /topic/how-to-play/{gameId} so the frontend can show a live progress bar
 * without polling.
 */
@Service
public class HowToPlayExtractionService {

    private static final Logger log = LoggerFactory.getLogger(HowToPlayExtractionService.class);
    private static final int TOP_CHUNKS = 10;
    private static final String LOCK_PREFIX = "lock:how-to-play:";
    private static final String PROGRESS_PREFIX = "progress:how-to-play:";
    private static final Duration LOCK_TTL = Duration.ofMinutes(10);

    private final GameHowToPlayRepository howToPlayRepository;
    private final RuleChunkRepository ruleChunkRepository;
    private final AiCompletionService completionService;
    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper;
    private final SimpMessagingTemplate messagingTemplate;

    public HowToPlayExtractionService(GameHowToPlayRepository howToPlayRepository,
                                      RuleChunkRepository ruleChunkRepository,
                                      AiCompletionService completionService,
                                      StringRedisTemplate redisTemplate,
                                      ObjectMapper objectMapper,
                                      SimpMessagingTemplate messagingTemplate) {
        this.howToPlayRepository = howToPlayRepository;
        this.ruleChunkRepository = ruleChunkRepository;
        this.completionService = completionService;
        this.redisTemplate = redisTemplate;
        this.objectMapper = objectMapper;
        this.messagingTemplate = messagingTemplate;
    }

    // -------------------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------------------

    @Async
    public void extractAsync(UUID gameId, Game game) {
        extract(gameId, game);
    }

    public void extract(UUID gameId, Game game) {
        String lockKey = LOCK_PREFIX + gameId;
        Boolean acquired = redisTemplate.opsForValue().setIfAbsent(lockKey, "1", LOCK_TTL);
        if (!Boolean.TRUE.equals(acquired)) {
            log.debug("How-to-play extraction already in progress for game {}", gameId);
            return;
        }

        try {
            pushProgress(gameId, 5);

            boolean hasChunks = ruleChunkRepository.existsByGame_Id(gameId);
            String sourceMode = hasChunks ? "rulebook" : "general";
            String context = buildContext(gameId, game, hasChunks);

            pushProgress(gameId, 15);

            // Pass 1: structure extraction
            Map<String, Object> structure = extractStructure(game.getNameEn(), context);
            pushProgress(gameId, 60);

            // Pass 2: FAQ + tips
            Map<String, Object> faqAndTips = extractFaqAndTips(game.getNameEn(), context);
            pushProgress(gameId, 90);

            // Merge pass 2 into pass 1
            structure.putAll(faqAndTips);

            // Upsert
            GameHowToPlay entity = howToPlayRepository.findByGame_Id(gameId)
                    .orElseGet(GameHowToPlay::new);
            entity.setGame(game);
            entity.setContent(structure);
            entity.setSourceMode(sourceMode);
            entity.setGeneratedAt(Instant.now());
            entity.setUpdatedAt(Instant.now());
            howToPlayRepository.save(entity);

            log.debug("How-to-play extracted for '{}' (mode={})", game.getNameEn(), sourceMode);

            // Signal completion over WebSocket
            redisTemplate.delete(PROGRESS_PREFIX + gameId);
            messagingTemplate.convertAndSend(
                    "/topic/how-to-play/" + gameId,
                    Map.of("status", "ready", "progress", 100));

        } catch (Exception e) {
            log.error("How-to-play extraction failed for game {}: {}", gameId, e.getMessage(), e);
            messagingTemplate.convertAndSend(
                    "/topic/how-to-play/" + gameId,
                    Map.of("status", "error", "progress", 0));
        } finally {
            redisTemplate.delete(lockKey);
            redisTemplate.delete(PROGRESS_PREFIX + gameId);
        }
    }

    /** Returns true if an extraction is currently running for this game. */
    public boolean isGenerating(UUID gameId) {
        return Boolean.TRUE.equals(redisTemplate.hasKey(LOCK_PREFIX + gameId));
    }

    /** Returns the current progress (0–100) from Redis; 0 if not tracked. */
    public int getProgress(UUID gameId) {
        String val = redisTemplate.opsForValue().get(PROGRESS_PREFIX + gameId);
        if (val == null) return 0;
        try { return Integer.parseInt(val); } catch (NumberFormatException e) { return 0; }
    }

    // -------------------------------------------------------------------------
    // Progress helpers
    // -------------------------------------------------------------------------

    private void pushProgress(UUID gameId, int pct) {
        redisTemplate.opsForValue().set(PROGRESS_PREFIX + gameId, String.valueOf(pct), LOCK_TTL);
        messagingTemplate.convertAndSend(
                "/topic/how-to-play/" + gameId,
                Map.of("status", "generating", "progress", pct));
    }

    // -------------------------------------------------------------------------
    // Context building
    // -------------------------------------------------------------------------

    private String buildContext(UUID gameId, Game game, boolean hasChunks) {
        if (hasChunks) {
            return ruleChunkRepository
                    .findByGame_IdOrderByChunkIndexAsc(gameId, PageRequest.of(0, TOP_CHUNKS))
                    .stream()
                    .map(RuleChunk::getChunkText)
                    .collect(Collectors.joining("\n\n---\n\n"));
        }
        // General knowledge fallback: use BGG description
        String desc = game.getGameDetail() != null ? game.getGameDetail().getDescription() : null;
        return desc != null ? desc : "No rulebook or description available.";
    }

    // -------------------------------------------------------------------------
    // Pass 1 — structure
    // -------------------------------------------------------------------------

    private Map<String, Object> extractStructure(String gameName, String context) throws Exception {
        String prompt = """
                You are a board game expert. Based on the provided rules, extract a structured 'How to Play' guide for %s.
                Return ONLY a valid JSON object matching this schema exactly. Omit any key whose value is unknown or not applicable.
                Keep text values concise to avoid truncation. Do not include markdown, comments, or extra text.

                {
                  "overview": "string",
                  "objective": "string",
                  "setup": "string",
                  "winCondition": { "type": "string", "details": "string" },
                  "gameStructure": {
                    "mode": "string",
                    "turnOrder": "string",
                    "phases": [{ "name": "string", "description": "string", "actions": ["string"] }]
                  },
                  "resources": [{ "name": "string", "usedFor": "string", "gainedBy": "string" }],
                  "actions": [{ "name": "string", "type": "string", "cost": "string", "effect": "string" }],
                  "cardSystem": { "exists": true, "cardTypes": [{ "name": "string", "description": "string" }], "deckRules": "string", "handRules": "string" },
                  "board": { "exists": true, "type": "string", "description": "string" },
                  "roles": { "exists": false, "list": [{ "name": "string", "abilities": "string", "winCondition": "string" }] },
                  "variants": [{ "name": "string", "description": "string" }],
                  "rules": { "coreRules": "string", "specialRules": [{ "name": "string", "description": "string" }], "edgeCases": "string" },
                  "scoring": { "exists": true, "methods": [{ "item": "string", "points": "string" }] },
                  "endCondition": { "trigger": "string", "notes": "string" },
                  "components": [{ "name": "string", "type": "string", "quantity": 1 }]
                }

                GAME RULES CONTEXT:
                """.formatted(gameName) + context;

        String json = completionService.complete(
                List.of(Map.of("role", "user", "content", prompt)), 2500, 0.2);

        return parseJson(json);
    }

    // -------------------------------------------------------------------------
    // Pass 2 — FAQ + tips
    // -------------------------------------------------------------------------

    private Map<String, Object> extractFaqAndTips(String gameName, String context) throws Exception {
        String prompt = """
                Based on the rules for %s below, generate:
                - 3 to 5 beginner FAQ pairs (common misunderstandings, edge cases)
                - 3 to 5 practical tips for new players

                Output pure JSON only — no markdown, no explanation:
                {
                  "faq": [{"question":"","answer":""}],
                  "tips": [""]
                }

                GAME RULES CONTEXT:
                """.formatted(gameName) + context;

        String json = completionService.complete(
                List.of(Map.of("role", "user", "content", prompt)), 700, 0.3);

        return parseJson(json);
    }

    // -------------------------------------------------------------------------
    // JSON parsing helper
    // -------------------------------------------------------------------------

    private Map<String, Object> parseJson(String raw) {
        String cleaned = raw.strip();
        if (cleaned.startsWith("```")) {
            cleaned = cleaned.replaceAll("^```[a-z]*\\n?", "").replaceAll("```$", "").strip();
        }

        try {
            return new HashMap<>(objectMapper.readValue(cleaned, new TypeReference<Map<String, Object>>() {}));
        } catch (Exception e) {
            log.debug("Standard JSON parse failed, attempting repair... ({})", e.getMessage());
            try {
                String repaired = repairJson(cleaned);
                return new HashMap<>(objectMapper.readValue(repaired, new TypeReference<Map<String, Object>>() {}));
            } catch (Exception re) {
                log.warn("Failed to parse/repair LLM JSON response for rulebook extraction: {}", re.getMessage());
                Map<String, Object> fallback = new HashMap<>();
                fallback.put("raw", cleaned);
                return fallback;
            }
        }
    }

    private String repairJson(String json) {
        String result = json.strip();

        long quotes = result.chars().filter(ch -> ch == '"').count();
        if (quotes % 2 != 0) result += "\"";

        int openBraces = 0;
        int openBrackets = 0;
        boolean inString = false;
        char prev = '\0';

        for (char c : result.toCharArray()) {
            if (c == '"' && prev != '\\') inString = !inString;
            if (!inString) {
                if (c == '{') openBraces++;
                else if (c == '}') openBraces--;
                else if (c == '[') openBrackets++;
                else if (c == ']') openBrackets--;
            }
            prev = c;
        }

        while (openBrackets > 0) { result += "]"; openBrackets--; }
        while (openBraces > 0) { result += "}"; openBraces--; }

        return result;
    }
}
