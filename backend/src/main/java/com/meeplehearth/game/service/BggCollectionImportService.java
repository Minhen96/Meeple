package com.meeplehearth.game.service;

import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.game.client.BggApiClient;
import com.meeplehearth.game.client.BggCollectionClient;
import com.meeplehearth.game.client.BggCollectionClient.CollectionItem;
import com.meeplehearth.game.config.BggImportExecutorConfig;
import com.meeplehearth.game.dto.BggImportStatusResponse;
import com.meeplehearth.game.dto.BggImportStatusResponse.PreviewGame;
import com.meeplehearth.game.entity.BggImport;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.entity.UserGame;
import com.meeplehearth.game.repository.BggImportRepository;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.game.repository.UserGameRepository;
import com.meeplehearth.notification.entity.Notification;
import com.meeplehearth.notification.service.NotificationService;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.core.task.TaskExecutor;
import org.springframework.core.task.TaskRejectedException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Instant;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Imports a user's owned BoardGameGeek collection (FEATURES_COMPLETE section 3.2, SCREENS section 3.4).
 *
 * <p>{@link #start} validates and returns at once (202); the import runs on the
 * {@code bggImportExecutor} pool: fetch the collection (with 202 polling, see
 * {@link BggCollectionClient}), then upsert games and {@code user_games.is_owned=true} in short
 * transactions of {@value #CHUNK_SIZE} items, publishing progress to Redis after each chunk.
 * Existing wishlist/favourite flags are kept. Games new to the catalog are inserted from the
 * collection data and hydrated in the background through the existing BGG hydration path.
 * On success the user gets a {@code BGG_IMPORT_COMPLETED} notification.
 */
@Service
public class BggCollectionImportService {

    private static final Logger log = LoggerFactory.getLogger(BggCollectionImportService.class);

    public static final String BGG_USER_NOT_FOUND = "BGG_USER_NOT_FOUND";
    public static final String BGG_API_UNAVAILABLE = "BGG_API_UNAVAILABLE";
    public static final String BGG_IMPORT_IN_PROGRESS = "BGG_IMPORT_IN_PROGRESS";

    static final int CHUNK_SIZE = 20;
    static final int PREVIEW_SIZE = 5;

    private final BggCollectionClient client;
    private final BggImportProgressStore progressStore;
    private final BggImportRepository importRepository;
    private final GameRepository gameRepository;
    private final UserGameRepository userGameRepository;
    private final UserRepository userRepository;
    private final GameHydrationService hydrationService;
    private final RecommendationService recommendationService;
    private final GameCacheEvictor cacheEvictor;
    private final NotificationService notificationService;
    private final TaskExecutor executor;
    private final TransactionTemplate tx;

    public BggCollectionImportService(BggCollectionClient client,
                                      BggImportProgressStore progressStore,
                                      BggImportRepository importRepository,
                                      GameRepository gameRepository,
                                      UserGameRepository userGameRepository,
                                      UserRepository userRepository,
                                      GameHydrationService hydrationService,
                                      RecommendationService recommendationService,
                                      GameCacheEvictor cacheEvictor,
                                      NotificationService notificationService,
                                      @Qualifier(BggImportExecutorConfig.BGG_IMPORT_EXECUTOR) TaskExecutor executor,
                                      PlatformTransactionManager transactionManager) {
        this.client = client;
        this.progressStore = progressStore;
        this.importRepository = importRepository;
        this.gameRepository = gameRepository;
        this.userGameRepository = userGameRepository;
        this.userRepository = userRepository;
        this.hydrationService = hydrationService;
        this.recommendationService = recommendationService;
        this.cacheEvictor = cacheEvictor;
        this.notificationService = notificationService;
        this.executor = executor;
        this.tx = new TransactionTemplate(transactionManager);
    }

    /**
     * Saves the BGG username on the user and queues the import.
     *
     * @return the "running" status
     * @throws ApiException 503 BGG_API_UNAVAILABLE when no BGG token is configured or the import
     *                      cannot be queued; 409 BGG_IMPORT_IN_PROGRESS while an import runs
     */
    public BggImportStatusResponse start(UUID userId, String bggUsername) {
        String username = bggUsername.strip();
        tx.executeWithoutResult(status -> {
            User user = userRepository.findById(userId)
                    .orElseThrow(() -> ApiException.notFound("User not found"));
            user.setBggUsername(username);
            userRepository.save(user);
        });

        if (!client.isConfigured()) {
            progressStore.save(userId, BggImportStatusResponse.failed(BGG_API_UNAVAILABLE));
            throw unavailable();
        }
        if (!progressStore.tryLock(userId)) {
            throw ApiException.conflict(BGG_IMPORT_IN_PROGRESS, "A BoardGameGeek import is already running");
        }

        try {
            BggImport audit = new BggImport();
            audit.setUserId(userId);
            audit.setBggUsername(username);
            UUID importId = importRepository.save(audit).getId();

            BggImportStatusResponse running = BggImportStatusResponse.running();
            progressStore.save(userId, running);
            executor.execute(() -> run(userId, username, importId));
            return running;
        } catch (TaskRejectedException e) {
            log.warn("BGG import queue is full; rejecting import for user {}", userId);
            progressStore.save(userId, BggImportStatusResponse.failed(BGG_API_UNAVAILABLE));
            progressStore.unlock(userId);
            throw unavailable();
        } catch (RuntimeException e) {
            progressStore.unlock(userId);
            throw e;
        }
    }

    public BggImportStatusResponse status(UUID userId) {
        return progressStore.get(userId);
    }

    /** The import body; runs on the import executor and never throws. */
    void run(UUID userId, String username, UUID importId) {
        Counts counts = new Counts();
        try {
            List<CollectionItem> items = client.fetchOwnedCollection(username);
            counts.total = items.size();
            progressStore.save(userId, counts.toStatus(BggImportStatusResponse.RUNNING, null));

            Set<Long> seen = new HashSet<>();
            List<CollectionItem> unique = new ArrayList<>(items.size());
            for (CollectionItem item : items) {
                if (item.bggId() == null || item.name() == null) {
                    counts.failed++;
                    counts.processed++;
                } else if (!seen.add(item.bggId())) {
                    counts.skipped++; // the same game listed twice (several copies owned)
                    counts.processed++;
                } else {
                    unique.add(item);
                }
            }

            List<Long> newGames = new ArrayList<>();
            for (int from = 0; from < unique.size(); from += CHUNK_SIZE) {
                List<CollectionItem> chunk = unique.subList(from, Math.min(from + CHUNK_SIZE, unique.size()));
                importChunkWithRetry(userId, chunk, counts, newGames);
                counts.processed += chunk.size();
                progressStore.touchLock(userId);
                progressStore.save(userId, counts.toStatus(BggImportStatusResponse.RUNNING, null));
            }

            finish(userId, importId, counts, BggImport.Status.DONE, null);
            if (!newGames.isEmpty()) {
                hydrationService.hydrateImagesQuietly(newGames);
            }
            notifyCompleted(userId, importId);
        } catch (BggCollectionClient.BggUserNotFoundException e) {
            finish(userId, importId, counts, BggImport.Status.FAILED, BGG_USER_NOT_FOUND);
        } catch (BggApiClient.BggUnavailableException e) {
            log.warn("BGG import for user {} failed: {}", userId, e.getMessage());
            finish(userId, importId, counts, BggImport.Status.FAILED, BGG_API_UNAVAILABLE);
        } catch (RuntimeException e) {
            log.error("BGG import for user {} failed unexpectedly", userId, e);
            finish(userId, importId, counts, BggImport.Status.FAILED, BGG_API_UNAVAILABLE);
        } finally {
            progressStore.unlock(userId);
        }
    }

    /** A concurrent insert of the same new game (another import, a detail lookup) aborts the chunk once. */
    private void importChunkWithRetry(UUID userId, List<CollectionItem> chunk, Counts counts, List<Long> newGames) {
        ChunkResult result;
        try {
            result = tx.execute(status -> importChunk(userId, chunk));
        } catch (DataIntegrityViolationException e) {
            result = tx.execute(status -> importChunk(userId, chunk));
        }
        if (result == null) return;
        counts.imported += result.imported;
        counts.skipped += result.skipped;
        newGames.addAll(result.newGames);
        for (PreviewGame p : result.preview) {
            if (counts.preview.size() < PREVIEW_SIZE) counts.preview.add(p);
        }
    }

    private ChunkResult importChunk(UUID userId, List<CollectionItem> chunk) {
        Set<Long> bggIds = chunk.stream().map(CollectionItem::bggId).collect(Collectors.toSet());
        Map<Long, Game> games = new LinkedHashMap<>(gameRepository.findByBggIdIn(bggIds).stream()
                .collect(Collectors.toMap(Game::getBggId, Function.identity(), (a, b) -> a)));

        ChunkResult result = new ChunkResult();
        List<Game> created = new ArrayList<>();
        for (CollectionItem item : chunk) {
            if (!games.containsKey(item.bggId())) {
                Game game = new Game();
                game.setBggId(item.bggId());
                game.setNameEn(item.name());
                game.setYearPublished(item.yearPublished());
                game.setThumbnailUrl(item.thumbnailUrl());
                game.setImageUrl(item.imageUrl() != null ? item.imageUrl() : item.thumbnailUrl());
                game.setGameType(item.subtype() != null ? item.subtype() : "boardgame");
                created.add(game);
                games.put(item.bggId(), game);
                result.newGames.add(item.bggId());
            }
        }
        if (!created.isEmpty()) {
            gameRepository.saveAllAndFlush(created);
        }

        Map<Long, UserGame> entries = userGameRepository.findByUserIdAndGameBggIdIn(userId, bggIds).stream()
                .collect(Collectors.toMap(ug -> ug.getGame().getBggId(), Function.identity(), (a, b) -> a));
        User user = userRepository.getReferenceById(userId);
        List<UserGame> toSave = new ArrayList<>();
        for (CollectionItem item : chunk) {
            Game game = games.get(item.bggId());
            UserGame entry = entries.get(item.bggId());
            if (entry != null && entry.isOwned()) {
                result.skipped++;
                continue;
            }
            if (entry == null) {
                entry = new UserGame();
                entry.setUser(user);
                entry.setGame(game);
            }
            entry.setOwned(true);
            toSave.add(entry);
            result.imported++;
            result.preview.add(new PreviewGame(game.getId(), game.getNameEn(), game.getThumbnailUrl()));
        }
        userGameRepository.saveAll(toSave);
        return result;
    }

    private void finish(UUID userId, UUID importId, Counts counts, BggImport.Status status, String errorCode) {
        String publicStatus = status == BggImport.Status.DONE
                ? BggImportStatusResponse.DONE : BggImportStatusResponse.FAILED;
        if (status == BggImport.Status.DONE) {
            counts.processed = counts.total;
        }
        try {
            progressStore.save(userId, counts.toStatus(publicStatus, errorCode));
        } catch (RuntimeException e) {
            log.warn("Could not publish final BGG import status for user {}", userId, e);
        }
        try {
            tx.executeWithoutResult(s -> importRepository.findById(importId).ifPresent(audit -> {
                audit.setStatus(status);
                audit.setTotal(counts.total);
                audit.setImported(counts.imported);
                audit.setSkipped(counts.skipped);
                audit.setFailed(counts.failed);
                audit.setErrorCode(errorCode);
                audit.setFinishedAt(Instant.now());
                importRepository.save(audit);
            }));
        } catch (RuntimeException e) {
            log.warn("Could not record BGG import {} result", importId, e);
        }
        if (counts.imported > 0) {
            cacheEvictor.evictCollection(userId);
            recommendationService.invalidateCache(userId);
        }
    }

    private void notifyCompleted(UUID userId, UUID importId) {
        try {
            notificationService.send(userId, Notification.NotificationType.BGG_IMPORT_COMPLETED,
                    null, importId, "BGG_IMPORT");
        } catch (RuntimeException e) {
            log.warn("Could not send BGG_IMPORT_COMPLETED to user {}", userId, e);
        }
    }

    private static ApiException unavailable() {
        return new ApiException(HttpStatus.SERVICE_UNAVAILABLE, BGG_API_UNAVAILABLE,
                "BoardGameGeek is unavailable right now. Try again later.");
    }

    private static final class ChunkResult {
        int imported;
        int skipped;
        final List<Long> newGames = new ArrayList<>();
        final List<PreviewGame> preview = new ArrayList<>();
    }

    private static final class Counts {
        int total;
        int processed;
        int imported;
        int skipped;
        int failed;
        final List<PreviewGame> preview = new ArrayList<>();

        BggImportStatusResponse toStatus(String status, String errorCode) {
            return new BggImportStatusResponse(status, total, processed, imported, skipped, failed, errorCode,
                    preview);
        }
    }
}
