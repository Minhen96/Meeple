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
 * Result stored in game_how_to_play as JSONB.
 * Re-runs automatically whenever a new rulebook is ingested (called by RulebookIngestionService).
 *
 * A 10-minute Redis lock prevents concurrent extractions for the same game.
 */
@Service
public class HowToPlayExtractionService {

    private static final Logger log = LoggerFactory.getLogger(HowToPlayExtractionService.class);
    private static final int TOP_CHUNKS = 20;
    private static final String LOCK_PREFIX = "lock:how-to-play:";
    private static final Duration LOCK_TTL = Duration.ofMinutes(10);

    private final GameHowToPlayRepository howToPlayRepository;
    private final RuleChunkRepository ruleChunkRepository;
    private final AiCompletionService completionService;
    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper;

    public HowToPlayExtractionService(GameHowToPlayRepository howToPlayRepository,
                                      RuleChunkRepository ruleChunkRepository,
                                      AiCompletionService completionService,
                                      StringRedisTemplate redisTemplate,
                                      ObjectMapper objectMapper) {
        this.howToPlayRepository = howToPlayRepository;
        this.ruleChunkRepository = ruleChunkRepository;
        this.completionService = completionService;
        this.redisTemplate = redisTemplate;
        this.objectMapper = objectMapper;
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
            boolean hasChunks = ruleChunkRepository.existsByGame_Id(gameId);
            String sourceMode = hasChunks ? "rulebook" : "general";
            String context = buildContext(gameId, game, hasChunks);

            // Pass 1: structure extraction
            Map<String, Object> structure = extractStructure(game.getNameEn(), context);

            // Pass 2: FAQ + tips
            Map<String, Object> faqAndTips = extractFaqAndTips(game.getNameEn(), context);

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

            log.info("How-to-play extracted for '{}' (mode={})", game.getNameEn(), sourceMode);

        } catch (Exception e) {
            log.error("How-to-play extraction failed for game {}: {}", gameId, e.getMessage(), e);
        } finally {
            redisTemplate.delete(lockKey);
        }
    }

    /** Returns true if an extraction is currently running for this game. */
    public boolean isGenerating(UUID gameId) {
        return Boolean.TRUE.equals(redisTemplate.hasKey(LOCK_PREFIX + gameId));
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
                You are a rule extraction engine. Analyze the provided game rules for %s and output a structured JSON.
                Include ONLY fields relevant to this specific game. Omit null/empty/false fields.
                Output pure JSON only — no markdown, no explanation.

                Required schema (include only applicable fields):
                {
                  "overview": "",
                  "objective": "",
                  "gameStructure": { "mode": "", "phases": [{"name":"","description":"","actions":[]}], "turnOrder": "" },
                  "components": [{"name":"","type":"","description":"","quantity":0}],
                  "board": {"exists":true,"type":"","description":""},
                  "resources": [{"name":"","type":"","usedFor":"","gainedBy":""}],
                  "cardSystem": {"exists":true,"cardTypes":[{"name":"","description":""}],"deckRules":"","handRules":""},
                  "actions": [{"name":"","type":"","cost":"","effect":"","constraints":""}],
                  "rules": {"coreRules":"","specialRules":[{"name":"","description":""}],"edgeCases":""},
                  "winCondition": {"type":"","details":""},
                  "scoring": {"exists":true,"methods":[{"item":"","points":""}]},
                  "endCondition": {"trigger":"","notes":""},
                  "roles": {"exists":true,"list":[{"name":"","abilities":"","winCondition":""}]},
                  "variants": [{"name":"","description":""}]
                }

                GAME RULES CONTEXT:
                """.formatted(gameName) + context;

        String json = completionService.complete(
                List.of(Map.of("role", "user", "content", prompt)), 2000, 0.2);

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
                List.of(Map.of("role", "user", "content", prompt)), 800, 0.3);

        return parseJson(json);
    }

    // -------------------------------------------------------------------------
    // JSON parsing helper
    // -------------------------------------------------------------------------

    private Map<String, Object> parseJson(String raw) {
        // Strip markdown code fences if the LLM wrapped the output
        String cleaned = raw.strip();
        if (cleaned.startsWith("```")) {
            cleaned = cleaned.replaceAll("^```[a-z]*\\n?", "").replaceAll("```$", "").strip();
        }
        try {
            return objectMapper.readValue(cleaned, new TypeReference<>() {});
        } catch (Exception e) {
            log.warn("Failed to parse LLM JSON response, storing as raw text: {}", e.getMessage());
            return Map.of("raw", cleaned);
        }
    }
}
