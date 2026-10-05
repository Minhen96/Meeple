package com.meeplehearth.ai.service;

import com.meeplehearth.ai.entity.GameRulebook;
import com.meeplehearth.ai.entity.RuleChunk;
import com.meeplehearth.ai.repository.GameRulebookRepository;
import com.meeplehearth.ai.repository.RuleChunkRepository;
import com.meeplehearth.game.repository.GameRepository;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Short DB transactions for the ingestion pipeline. Kept in a separate bean from
 * {@link RulebookIngestionService} so the @Transactional proxy actually applies, and
 * so no transaction is ever held open across PDF download / embedding HTTP calls.
 */
@Component
public class RulebookChunkWriter {

    /** One embedded chunk, computed outside any transaction. */
    public record EmbeddedChunk(String text, int index, int tokenCount, String embedding) {}

    private final GameRulebookRepository rulebookRepository;
    private final RuleChunkRepository ruleChunkRepository;
    private final GameRepository gameRepository;

    public RulebookChunkWriter(GameRulebookRepository rulebookRepository,
                               RuleChunkRepository ruleChunkRepository,
                               GameRepository gameRepository) {
        this.rulebookRepository = rulebookRepository;
        this.ruleChunkRepository = ruleChunkRepository;
        this.gameRepository = gameRepository;
    }

    /**
     * Atomic swap in ONE transaction: delete the game's old chunks, insert the new ones,
     * mark the rulebook approved. No-op (returns false) if the rulebook no longer exists
     * or is no longer 'ingesting' (e.g. superseded while embeddings were computed).
     */
    @Transactional
    public boolean replaceChunks(UUID rulebookId, List<EmbeddedChunk> chunks) {
        GameRulebook rulebook = rulebookRepository.findByIdWithGame(rulebookId).orElse(null);
        if (rulebook == null || !"ingesting".equals(rulebook.getStatus())) {
            return false;
        }

        // Serialize concurrent swaps for the same game (row lock on games, held for this short tx)
        gameRepository.findByIdForUpdate(rulebook.getGame().getId());

        ruleChunkRepository.deleteByGameId(rulebook.getGame().getId());

        List<RuleChunk> entities = new ArrayList<>(chunks.size());
        for (EmbeddedChunk c : chunks) {
            RuleChunk rc = new RuleChunk();
            rc.setGame(rulebook.getGame());
            rc.setRulebookId(rulebookId);
            rc.setChunkText(c.text());
            rc.setChunkIndex(c.index());
            rc.setTokenCount(c.tokenCount());
            rc.setEmbedding(c.embedding());
            entities.add(rc);
        }
        ruleChunkRepository.saveAll(entities);

        rulebook.setStatus("approved");
        rulebookRepository.save(rulebook);
        return true;
    }

    /**
     * Marks an 'ingesting' rulebook as failed (no-op for any other status). Always in its own
     * transaction: it is also called from after-commit callbacks, where joining the finished
     * transaction would silently never commit.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void markFailed(UUID rulebookId) {
        rulebookRepository.findById(rulebookId).ifPresent(rulebook -> {
            if ("ingesting".equals(rulebook.getStatus())) {
                rulebook.setStatus("failed");
                rulebookRepository.save(rulebook);
            }
        });
    }
}
