package com.meeplehearth.game.service;

import com.meeplehearth.common.event.SessionPlayedEvent;
import com.meeplehearth.common.event.UserSoftDeletedEvent;
import com.meeplehearth.game.entity.PlayLog;
import com.meeplehearth.game.repository.BggImportRepository;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.game.repository.PlayLogRepository;
import com.meeplehearth.game.repository.UserGameRepository;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

/**
 * Reacts to other packages' domain events after their transaction commits:
 * <ul>
 *   <li>{@link SessionPlayedEvent} (a post with a game tagged players): +1 play and a play log per
 *       player, at most once per (user, post), so a re-delivered event changes nothing;</li>
 *   <li>{@link UserSoftDeletedEvent}: the collection, play logs and BGG import history are deleted
 *       immediately (FEATURES_COMPLETE section 1.6).</li>
 * </ul>
 * Each runs in its own transaction; failures are logged and never reach the publisher, whose
 * transaction has already committed.
 */
@Component
public class LibraryEventListener {

    private static final Logger log = LoggerFactory.getLogger(LibraryEventListener.class);

    private final UserGameRepository userGameRepository;
    private final PlayLogRepository playLogRepository;
    private final BggImportRepository bggImportRepository;
    private final GameRepository gameRepository;
    private final UserRepository userRepository;
    private final GameCacheEvictor cacheEvictor;
    private final RecommendationService recommendationService;
    private final BggImportProgressStore progressStore;
    private final TransactionTemplate requiresNew;

    public LibraryEventListener(UserGameRepository userGameRepository,
                                PlayLogRepository playLogRepository,
                                BggImportRepository bggImportRepository,
                                GameRepository gameRepository,
                                UserRepository userRepository,
                                GameCacheEvictor cacheEvictor,
                                RecommendationService recommendationService,
                                BggImportProgressStore progressStore,
                                PlatformTransactionManager transactionManager) {
        this.userGameRepository = userGameRepository;
        this.playLogRepository = playLogRepository;
        this.bggImportRepository = bggImportRepository;
        this.gameRepository = gameRepository;
        this.userRepository = userRepository;
        this.cacheEvictor = cacheEvictor;
        this.recommendationService = recommendationService;
        this.progressStore = progressStore;
        this.requiresNew = new TransactionTemplate(transactionManager);
        this.requiresNew.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onSessionPlayed(SessionPlayedEvent event) {
        try {
            List<UUID> recorded = requiresNew.execute(status -> recordSession(event));
            if (recorded != null) {
                recorded.forEach(userId -> {
                    cacheEvictor.evictCollection(userId);
                    recommendationService.invalidateCache(userId);
                });
            }
        } catch (RuntimeException e) {
            log.error("Recording session plays for post {} failed", event.postId(), e);
        }
    }

    /** @return the users whose play count changed */
    List<UUID> recordSession(SessionPlayedEvent event) {
        if (event.gameId() == null || event.userIds().isEmpty() || !gameRepository.existsById(event.gameId())) {
            return List.of();
        }
        Instant playedAt = event.playedAt() != null ? event.playedAt() : Instant.now();
        List<UUID> candidates = new LinkedHashSet<>(event.userIds()).stream().filter(Objects::nonNull).toList();
        List<UUID> players = userRepository.findAllById(candidates).stream()
                .filter(u -> u.getDeletedAt() == null)
                .map(User::getId)
                .toList();

        List<UUID> recorded = new ArrayList<>();
        for (UUID userId : players) {
            boolean firstTime = event.postId() == null
                    ? insertManual(userId, event.gameId(), playedAt)
                    : playLogRepository.insertForPostIfAbsent(userId, event.gameId(), playedAt, event.postId()) == 1;
            if (firstTime) {
                userGameRepository.incrementPlayCount(userId, event.gameId());
                recorded.add(userId);
            }
        }
        return recorded;
    }

    private boolean insertManual(UUID userId, UUID gameId, Instant playedAt) {
        PlayLog playLog = new PlayLog();
        playLog.setUser(userRepository.getReferenceById(userId));
        playLog.setGame(gameRepository.getReferenceById(gameId));
        playLog.setPlayedAt(playedAt);
        playLogRepository.save(playLog);
        return true;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onUserSoftDeleted(UserSoftDeletedEvent event) {
        UUID userId = event.userId();
        try {
            requiresNew.executeWithoutResult(status -> {
                playLogRepository.deleteAllByUserId(userId);
                userGameRepository.deleteAllByUserId(userId);
                bggImportRepository.deleteAllByUserId(userId);
            });
            progressStore.clear(userId);
            cacheEvictor.evictCollection(userId);
            recommendationService.invalidateCache(userId);
        } catch (RuntimeException e) {
            log.error("Deleting library data of soft-deleted user {} failed", userId, e);
        }
    }
}
