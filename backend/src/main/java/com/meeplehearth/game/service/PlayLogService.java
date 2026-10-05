package com.meeplehearth.game.service;

import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.game.dto.LogPlayRequest;
import com.meeplehearth.game.dto.PlayLogResponse;
import com.meeplehearth.game.dto.UserGameResponse;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.entity.PlayLog;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.game.repository.PlayLogRepository;
import com.meeplehearth.game.repository.UserGameRepository;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/** Manual play logging: every play is a {@code play_logs} row plus +1 on the entry's play count. */
@Service
public class PlayLogService {

    /** Client clocks drift: a play "now" may arrive slightly in the future. */
    static final Duration MAX_CLOCK_SKEW = Duration.ofMinutes(5);

    private final PlayLogRepository playLogRepository;
    private final UserGameRepository userGameRepository;
    private final GameRepository gameRepository;
    private final UserRepository userRepository;
    private final RecommendationService recommendationService;
    private final GameCacheEvictor cacheEvictor;

    public PlayLogService(PlayLogRepository playLogRepository,
                          UserGameRepository userGameRepository,
                          GameRepository gameRepository,
                          UserRepository userRepository,
                          RecommendationService recommendationService,
                          GameCacheEvictor cacheEvictor) {
        this.playLogRepository = playLogRepository;
        this.userGameRepository = userGameRepository;
        this.gameRepository = gameRepository;
        this.userRepository = userRepository;
        this.recommendationService = recommendationService;
        this.cacheEvictor = cacheEvictor;
    }

    /**
     * Logs one play. Creates the collection entry (no flags set) if needed; flags are not changed.
     *
     * @throws ApiException 400 INVALID_PLAYED_AT for a play in the future, 404 GAME_NOT_FOUND
     */
    @Transactional
    public PlayLogResponse logPlay(UUID userId, UUID gameId, LogPlayRequest req) {
        LogPlayRequest body = req == null ? LogPlayRequest.empty() : req;
        Instant now = Instant.now();
        Instant playedAt = body.playedAt() == null ? now : body.playedAt();
        if (playedAt.isAfter(now.plus(MAX_CLOCK_SKEW))) {
            throw ApiException.badRequest("INVALID_PLAYED_AT", "A play cannot be in the future");
        }
        User user = userRepository.findById(userId)
                .orElseThrow(() -> ApiException.notFound("User not found"));
        Game game = gameRepository.findById(gameId)
                .orElseThrow(() -> ApiException.notFound("GAME_NOT_FOUND", "Game not found"));

        userGameRepository.incrementPlayCount(userId, gameId);

        PlayLog log = new PlayLog();
        log.setUser(user);
        log.setGame(game);
        log.setPlayedAt(playedAt);
        log.setNotes(body.notes() == null || body.notes().isBlank() ? null : body.notes().strip());
        log.setDurationMinutes(body.durationMinutes());
        log.setPlayerCount(body.playerCount());
        PlayLog saved = playLogRepository.save(log);

        cacheEvictor.evictCollection(userId);
        recommendationService.invalidateCache(userId);
        return PlayLogResponse.from(saved);
    }

    /** Legacy {@code POST .../log-play}: logs a play now and returns the updated collection entry. */
    @Transactional
    public UserGameResponse logPlayLegacy(UUID userId, UUID gameId) {
        logPlay(userId, gameId, LogPlayRequest.empty());
        return userGameRepository.findByUserIdAndGameId(userId, gameId)
                .map(UserGameResponse::from)
                .orElseThrow(() -> ApiException.notFound("COLLECTION_ENTRY_NOT_FOUND", "Game not in collection"));
    }

    /**
     * Deletes one of the caller's plays and decrements the play count; an entry left with nothing
     * on it is deleted too.
     *
     * @throws ApiException 404 PLAY_NOT_FOUND if the play does not exist or belongs to someone else
     */
    @Transactional
    public void deletePlay(UUID userId, UUID playId) {
        PlayLog log = playLogRepository.findByIdAndUserId(playId, userId)
                .orElseThrow(() -> ApiException.notFound("PLAY_NOT_FOUND", "Play not found"));
        UUID gameId = log.getGame().getId();
        playLogRepository.delete(log);
        playLogRepository.flush();
        userGameRepository.decrementPlayCount(userId, gameId);
        userGameRepository.deleteIfEmpty(userId, gameId);

        cacheEvictor.evictCollection(userId);
        recommendationService.invalidateCache(userId);
    }

    @Transactional(readOnly = true)
    public List<PlayLogResponse> getPlays(UUID userId, UUID gameId) {
        return playLogRepository.findByUserIdAndGameIdOrderByPlayedAtDesc(userId, gameId)
                .stream().map(PlayLogResponse::from).toList();
    }
}
