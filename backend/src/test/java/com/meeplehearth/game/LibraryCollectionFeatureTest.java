package com.meeplehearth.game;

import com.fasterxml.jackson.databind.JsonNode;
import com.meeplehearth.common.event.ActivityRecordedEvent;
import com.meeplehearth.config.CacheConfig.CacheNames;
import com.meeplehearth.support.social.ApiIntegrationTestBase;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.cache.CacheManager;
import org.springframework.http.MediaType;
import org.springframework.test.context.event.ApplicationEvents;
import org.springframework.test.context.event.RecordApplicationEvents;

import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Collection API end to end: wishlist flag, empty-entry deletion, filters, caching, activity events. */
@RecordApplicationEvents
class LibraryCollectionFeatureTest extends ApiIntegrationTestBase {

    @Autowired private CacheManager cacheManager;
    @Autowired private ApplicationEvents events;

    private JsonNode putEntry(UUID user, UUID game, Map<String, Object> body) throws Exception {
        return json(mvc.perform(put("/api/v1/users/me/games/{id}", game).with(as(user))
                        .contentType(MediaType.APPLICATION_JSON).content(toJson(body)))
                .andExpect(status().isOk())
                .andReturn()).get("data");
    }

    @Test
    void wishlistRoundTripAndFilter() throws Exception {
        UUID user = user();
        UUID wished = game();
        UUID owned = game();

        JsonNode entry = putEntry(user, wished, Map.of("isWishlisted", true));
        assertThat(entry.get("isWishlisted").asBoolean()).isTrue();
        assertThat(entry.get("isOwned").asBoolean()).isFalse();
        assertThat(entry.get("id").isNull()).isFalse();
        putEntry(user, owned, Map.of("isOwned", true, "isFavorited", true));

        assertThat(count("SELECT COUNT(*) FROM user_games WHERE user_id = ? AND game_id = ? AND is_wishlisted",
                user, wished)).isEqualTo(1);

        mvc.perform(get("/api/v1/users/me/games?filter=wishlisted").with(as(user)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.data[0].game.id").value(wished.toString()))
                .andExpect(jsonPath("$.data[0].isWishlisted").value(true));
        mvc.perform(get("/api/v1/users/me/games?filter=owned").with(as(user)))
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.data[0].game.id").value(owned.toString()));
        mvc.perform(get("/api/v1/users/me/games?filter=favorited").with(as(user)))
                .andExpect(jsonPath("$.data.length()").value(1));
        mvc.perform(get("/api/v1/users/me/games").with(as(user)))
                .andExpect(jsonPath("$.data.length()").value(2));
        mvc.perform(get("/api/v1/users/me/games?filter=played").with(as(user)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_FILTER"));
    }

    @Test
    void clearingTheLastFlagDeletesTheEntry() throws Exception {
        UUID user = user();
        UUID game = game();
        putEntry(user, game, Map.of("isWishlisted", true));

        JsonNode removed = putEntry(user, game, Map.of("isWishlisted", false));

        assertThat(removed.get("id").isNull()).isTrue();
        assertThat(removed.get("isWishlisted").asBoolean()).isFalse();
        assertThat(count("SELECT COUNT(*) FROM user_games WHERE user_id = ?", user)).isZero();
    }

    @Test
    void anEntryWithARatingSurvivesClearingFlagsAndRatingZeroClearsIt() throws Exception {
        UUID user = user();
        UUID game = game();
        putEntry(user, game, Map.of("isOwned", true, "personalRating", 8));

        JsonNode kept = putEntry(user, game, Map.of("isOwned", false));
        assertThat(kept.get("id").isNull()).isFalse();
        assertThat(kept.get("personalRating").asInt()).isEqualTo(8);

        JsonNode removed = putEntry(user, game, Map.of("personalRating", 0));
        assertThat(removed.get("id").isNull()).isTrue();
        assertThat(count("SELECT COUNT(*) FROM user_games WHERE user_id = ?", user)).isZero();
    }

    @Test
    void ratingBelowOneIsRejected() throws Exception {
        UUID user = user();
        UUID game = game();
        mvc.perform(put("/api/v1/users/me/games/{id}", game).with(as(user))
                        .contentType(MediaType.APPLICATION_JSON).content(toJson(Map.of("personalRating", 0.5))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_RATING"));
    }

    @Test
    void blankNotesAreStoredAsNullAndNewEntryWithOnlyBlankNotesIsNotCreated() throws Exception {
        UUID user = user();
        UUID game = game();
        JsonNode removed = putEntry(user, game, Map.of("notes", "   "));
        assertThat(removed.get("id").isNull()).isTrue();
        assertThat(count("SELECT COUNT(*) FROM user_games WHERE user_id = ?", user)).isZero();
    }

    @Test
    void collectionIsCachedAndEvictedOnEveryWrite() throws Exception {
        UUID user = user();
        UUID game = game();
        putEntry(user, game, Map.of("isOwned", true));

        mvc.perform(get("/api/v1/users/me/games").with(as(user)))
                .andExpect(jsonPath("$.data.length()").value(1));
        assertThat(cacheManager.getCache(CacheNames.USER_COLLECTION).get(user)).isNotNull();

        putEntry(user, game, Map.of("isFavorited", true));
        assertThat(cacheManager.getCache(CacheNames.USER_COLLECTION).get(user)).isNull();
        mvc.perform(get("/api/v1/users/me/games?filter=favorited").with(as(user)))
                .andExpect(jsonPath("$.data.length()").value(1));
        // Served from the cache now, still correct
        mvc.perform(get("/api/v1/users/me/games?filter=favorited").with(as(user)))
                .andExpect(jsonPath("$.data[0].isFavorited").value(true));

        mvc.perform(delete("/api/v1/users/me/games/{id}", game).with(as(user)))
                .andExpect(status().isNoContent());
        assertThat(cacheManager.getCache(CacheNames.USER_COLLECTION).get(user)).isNull();
        mvc.perform(get("/api/v1/users/me/games").with(as(user)))
                .andExpect(jsonPath("$.data.length()").value(0));
    }

    @Test
    void firstOwnershipPublishesCollectionAddOnce() throws Exception {
        UUID user = user();
        UUID game = game();

        putEntry(user, game, Map.of("isWishlisted", true));
        assertThat(collectionAdds(user)).isZero();

        putEntry(user, game, Map.of("isOwned", true));
        putEntry(user, game, Map.of("isFavorited", true)); // already owned: no second activity
        assertThat(collectionAdds(user)).isEqualTo(1);

        ActivityRecordedEvent event = events.stream(ActivityRecordedEvent.class)
                .filter(e -> e.userId().equals(user)).findFirst().orElseThrow();
        assertThat(event.data()).containsEntry("gameId", game.toString()).containsKey("gameTitle");
    }

    @Test
    void removingAMissingEntryIs404() throws Exception {
        mvc.perform(delete("/api/v1/users/me/games/{id}", game()).with(as(user())))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("COLLECTION_ENTRY_NOT_FOUND"));
    }

    @Test
    void unknownGameIs404() throws Exception {
        mvc.perform(put("/api/v1/users/me/games/{id}", UUID.randomUUID()).with(as(user()))
                        .contentType(MediaType.APPLICATION_JSON).content(toJson(Map.of("isOwned", true))))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("GAME_NOT_FOUND"));
    }

    private long collectionAdds(UUID user) {
        return events.stream(ActivityRecordedEvent.class)
                .filter(e -> e.userId().equals(user) && ActivityRecordedEvent.COLLECTION_ADD.equals(e.type()))
                .count();
    }
}
