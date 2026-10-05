package com.meeplehearth.game.service;

import com.meeplehearth.config.CacheConfig.CacheNames;
import com.meeplehearth.game.dto.UserGameResponse;
import com.meeplehearth.game.repository.UserGameRepository;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.UUID;

/**
 * A user's whole collection, cached in "user-collection" (10 min) keyed by user id. Tabs filter
 * this list in memory, so every write evicts a single key ({@link GameCacheEvictor#evictCollection}).
 * Separate bean so the cache proxy applies to callers inside the package.
 */
@Component
public class UserCollectionReader {

    private final UserGameRepository userGameRepository;

    public UserCollectionReader(UserGameRepository userGameRepository) {
        this.userGameRepository = userGameRepository;
    }

    /** Mutable ArrayList on purpose: the JSON cache serializer must be able to recreate the list type. */
    @Cacheable(cacheNames = CacheNames.USER_COLLECTION, key = "#userId")
    @Transactional(readOnly = true)
    public ArrayList<UserGameResponse> load(UUID userId) {
        return userGameRepository.findAllByUserId(userId).stream()
                .map(UserGameResponse::from)
                .collect(ArrayList::new, ArrayList::add, ArrayList::addAll);
    }
}
