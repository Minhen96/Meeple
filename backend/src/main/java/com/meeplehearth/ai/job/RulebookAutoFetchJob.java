package com.meeplehearth.ai.job;

import com.meeplehearth.ai.client.OnjRulebookClient;
import com.meeplehearth.ai.client.RuleBookOrgClient;
import com.meeplehearth.ai.entity.GameRulebook;
import com.meeplehearth.ai.repository.GameRulebookRepository;
import com.meeplehearth.ai.service.RulebookIngestionService;
import com.meeplehearth.game.entity.Game;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;

/**
 * One-time startup job: auto-fetches rulebooks for the top 2000 games by BGG
 * rank.
 *
 * Runs once on first application startup. A Redis flag (init:rulebook-fetch)
 * prevents
 * it from re-running on subsequent restarts. After the initial batch, new games
 * get
 * rulebooks either via the admin job trigger or through the on-demand "Generate
 * Rules"
 * button in the How To Play tab.
 *
 * Cost estimate: ~$0.40 one-time (text-embedding-3-small at $0.02/1M tokens).
 */
@Component
public class RulebookAutoFetchJob implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(RulebookAutoFetchJob.class);
    private static final String INIT_FLAG_KEY = "init:rulebook-fetch";
    private static final int INITIAL_BATCH_SIZE = 10000;

    private final GameRulebookRepository rulebookRepository;
    private final RulebookIngestionService ingestionService;
    private final RuleBookOrgClient ruleBookOrgClient;
    private final OnjRulebookClient onjClient;
    private final StringRedisTemplate redisTemplate;

    public RulebookAutoFetchJob(GameRulebookRepository rulebookRepository,
            RulebookIngestionService ingestionService,
            RuleBookOrgClient ruleBookOrgClient,
            OnjRulebookClient onjClient,
            StringRedisTemplate redisTemplate) {
        this.rulebookRepository = rulebookRepository;
        this.ingestionService = ingestionService;
        this.ruleBookOrgClient = ruleBookOrgClient;
        this.onjClient = onjClient;
        this.redisTemplate = redisTemplate;
    }

    // -------------------------------------------------------------------------
    // ApplicationRunner — fires once on first startup
    // -------------------------------------------------------------------------

    @Override
    public void run(ApplicationArguments args) {
        if (Boolean.TRUE.equals(redisTemplate.hasKey(INIT_FLAG_KEY))) {
            log.info("Rulebook initial fetch already done — skipping");
            return;
        }
        runBatchAsync();
    }

    @Async
    public void runBatchAsync() {
        runBatch(INITIAL_BATCH_SIZE, INIT_FLAG_KEY);
    }

    // -------------------------------------------------------------------------
    // Core batch logic — also callable from admin endpoint
    // -------------------------------------------------------------------------

    /**
     * Fetch rulebooks for up to {@code limit} games without an approved rulebook.
     * Sets {@code completionFlagKey} in Redis when done (pass null to skip).
     */
    public void runBatch(int limit, String completionFlagKey) {
        log.info("Rulebook auto-fetch starting (limit={})", limit);

        Instant ingestingCutoff = Instant.now().minus(Duration.ofHours(1));
        List<Game> games = rulebookRepository.findGamesWithoutApprovedRulebook(
                ingestingCutoff, PageRequest.of(0, limit));
        log.info("Found {} games without an approved rulebook", games.size());

        if (games.isEmpty()) {
            log.info("No games found — catalog may not be imported yet. Skipping flag set.");
            return;
        }

        int fetched = 0;
        for (Game game : games) {
            if (fetchForGame(game))
                fetched++;
        }

        log.info("Rulebook auto-fetch complete — fetched {}/{}", fetched, games.size());

        if (completionFlagKey != null) {
            redisTemplate.opsForValue().set(completionFlagKey, "1");
        }
    }

    // -------------------------------------------------------------------------
    // Single-game fetch (also used by on-demand endpoint)
    // -------------------------------------------------------------------------

    /**
     * Try to find and ingest a PDF for a single game.
     * Returns true if a rulebook was found and queued for ingestion.
     */
    public boolean fetchForGame(Game game) {
        // Skip if already approved or currently ingesting
        if (rulebookRepository.existsByGame_IdAndStatus(game.getId(), "approved")
                || rulebookRepository.existsByGame_IdAndStatus(game.getId(), "ingesting")) {
            return false;
        }

        String name = game.getNameEn();
        Optional<String> pdfUrl = ruleBookOrgClient.findPdfUrl(name);
        String source = "rule_book_org";

        if (pdfUrl.isEmpty()) {
            pdfUrl = onjClient.findPdfUrl(name);
            source = "onj";
        }

        if (pdfUrl.isEmpty()) {
            log.debug("No rulebook found for '{}'", name);
            return false;
        }

        try {
            GameRulebook rulebook = new GameRulebook();
            rulebook.setGame(game);
            rulebook.setSource(source);
            rulebook.setStatus("ingesting"); // promoted to "approved" only after chunks are stored
            rulebook.setPdfUrl(pdfUrl.get());
            rulebookRepository.save(rulebook);

            ingestionService.ingestAsync(rulebook.getId());

            log.info("Queued ingestion for '{}' via {} — {}", name, source, pdfUrl.get());
            return true;

        } catch (Exception e) {
            log.error("Failed to fetch/save rulebook for '{}': {}", name, e.getMessage());
            return false;
        }
    }
}
