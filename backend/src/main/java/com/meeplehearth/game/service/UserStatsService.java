package com.meeplehearth.game.service;

import com.meeplehearth.game.dto.UserStatsResponse;
import com.meeplehearth.game.repository.LibraryStatsQueries;
import org.springframework.stereotype.Service;

import java.util.UUID;

/** Profile stats bento (FEATURES_COMPLETE section 9.1; contract in docs/GAP_ANALYSIS.md section 6.1). */
@Service
public class UserStatsService {

    private final LibraryAccessGuard accessGuard;
    private final LibraryStatsQueries queries;

    public UserStatsService(LibraryAccessGuard accessGuard, LibraryStatsQueries queries) {
        this.accessGuard = accessGuard;
        this.queries = queries;
    }

    /** @throws com.meeplehearth.common.exception.ApiException 404 USER_NOT_FOUND if blocked either way or deleted */
    public UserStatsResponse getStats(UUID viewerId, UUID userId) {
        accessGuard.requireVisible(viewerId, userId);
        long[] ownedAndSessions = queries.ownedAndSessions(userId);
        return new UserStatsResponse(
                ownedAndSessions[0],
                ownedAndSessions[1],
                queries.friendCount(userId),
                queries.mostPlayedGame(userId),
                queries.favoriteCategory(userId),
                queries.mostPlayedWith(userId, viewerId),
                queries.totalPlayMinutes(userId));
    }
}
