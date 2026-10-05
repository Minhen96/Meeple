package com.meeplehearth.game.service;

import com.meeplehearth.game.dto.GameSummaryResponse;
import com.meeplehearth.support.ai.AiGameIntegrationTestBase;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;

import java.util.List;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;

import static org.assertj.core.api.Assertions.assertThat;

/** The native-SQL recommendation scoring (taste profile + friend signals) and its Redis cache. */
class RecommendationServiceIntegrationTest extends AiGameIntegrationTestBase {

    @Autowired private RecommendationService recommendationService;

    private final String tag = Long.toString(ThreadLocalRandom.current().nextLong(1L << 40), 36);

    private String m(String name) {
        return name + "-" + tag;
    }

    private List<String> titles(Page<GameSummaryResponse> page) {
        return page.getContent().stream().map(GameSummaryResponse::title).toList();
    }

    private void collect(UUID user, UUID game, boolean owned, boolean favorited, int plays) {
        jdbc.update("INSERT INTO user_games (user_id, game_id, is_owned, is_favorited, play_count) VALUES (?, ?, ?, ?, ?)",
                user, game, owned, favorited, plays);
    }

    @Test
    void coldStartUserGetsNothingAndNothingIsCached() {
        UUID user = createUser();
        game("Cold Candidate").mechanics(m("Any")).insert();

        assertThat(recommendationService.getRecommended(user, PageRequest.of(0, 10))).isEmpty();
        assertThat(redis.hasKey("rec:" + user)).isFalse();
    }

    @Test
    void scoresMechanicAndCategoryOverlapAndExcludesOwnedOrFavourited() {
        UUID user = createUser();
        UUID favourite = game("Fav").mechanics(m("Worker"), m("Engine")).categories(m("Economic")).insert();
        UUID played = game("Played").mechanics(m("Dice")).insert();
        collect(user, favourite, false, true, 0);
        collect(user, played, false, false, 2);

        game("Both fav mechanics").mechanics(m("Worker"), m("Engine")).insert();          // 0.50
        game("Played mechanic, top rated").mechanics(m("Dice")).rating("10").insert();     // 0.20 + 0.10
        game("Category only").categories(m("Economic")).insert();                          // 0.15
        game("Unrelated").mechanics(m("Nothing")).insert();
        UUID owned = game("Owned similar").mechanics(m("Worker")).insert();
        collect(user, owned, true, false, 0);

        Page<GameSummaryResponse> page = recommendationService.getRecommended(user, PageRequest.of(0, 10));

        // The played (not owned / favourited) game itself stays eligible: 0.20
        assertThat(titles(page)).containsExactly(
                "Both fav mechanics", "Played mechanic, top rated", "Played", "Category only");
        assertThat(page.getTotalElements()).isEqualTo(4);
    }

    @Test
    void acceptedFriendsActivityBoostsGames() {
        UUID user = createUser();
        UUID friend = createUser();
        UUID stranger = createUser();
        UUID favourite = game("Taste").mechanics(m("Deck")).insert();
        collect(user, favourite, false, true, 0);
        UUID plain = game("Plain deckbuilder").mechanics(m("Deck")).rating("9").insert();
        UUID friendsPick = game("Friends deckbuilder").mechanics(m("Deck")).rating("1").insert();
        jdbc.update("INSERT INTO friend_requests (sender_id, receiver_id, status) VALUES (?, ?, 'ACCEPTED')", friend, user);
        jdbc.update("INSERT INTO friend_requests (sender_id, receiver_id, status) VALUES (?, ?, 'PENDING')", user, stranger);
        collect(friend, friendsPick, true, false, 3);
        collect(stranger, plain, true, false, 9);

        // plain: 0.25 + 0.09 rating = 0.34 (the stranger's request is only pending, so no friend signal);
        // friendsPick: 0.25 + 1/5*0.15 + 1/5*0.10 + 0.01 rating = 0.31
        Page<GameSummaryResponse> page = recommendationService.getRecommended(user, PageRequest.of(0, 10));
        assertThat(titles(page)).containsExactly("Plain deckbuilder", "Friends deckbuilder");

        // Four more accepted friends playing and owning it push it to the top
        for (int i = 0; i < 4; i++) {
            UUID f = createUser();
            jdbc.update("INSERT INTO friend_requests (sender_id, receiver_id, status) VALUES (?, ?, 'ACCEPTED')", user, f);
            collect(f, friendsPick, true, false, 1);
        }
        recommendationService.invalidateCache(user);
        assertThat(titles(recommendationService.getRecommended(user, PageRequest.of(0, 10))))
                .containsExactly("Friends deckbuilder", "Plain deckbuilder");
    }

    @Test
    void resultsAreCachedUntilInvalidatedAndPaged() {
        UUID user = createUser();
        UUID favourite = game("Cache taste").mechanics(m("Tile")).insert();
        collect(user, favourite, false, true, 0);
        game("Tile A").mechanics(m("Tile")).rating("9").insert();
        game("Tile B").mechanics(m("Tile")).rating("8").insert();
        game("Tile C").mechanics(m("Tile")).rating("7").insert();

        Page<GameSummaryResponse> first = recommendationService.getRecommended(user, PageRequest.of(0, 2));
        assertThat(titles(first)).containsExactly("Tile A", "Tile B");
        assertThat(first.getTotalElements()).isEqualTo(3);
        assertThat(redis.opsForValue().get("rec:" + user)).startsWith("[\"");

        // New candidate is invisible while the cached pool is used
        game("Tile Z").mechanics(m("Tile")).rating("10").insert();
        assertThat(titles(recommendationService.getRecommended(user, PageRequest.of(1, 2)))).containsExactly("Tile C");
        assertThat(recommendationService.getRecommended(user, PageRequest.of(5, 2))).isEmpty();

        recommendationService.invalidateCache(user);
        assertThat(redis.hasKey("rec:" + user)).isFalse();
        assertThat(titles(recommendationService.getRecommended(user, PageRequest.of(0, 2))))
                .containsExactly("Tile Z", "Tile A");
    }

    @Test
    void corruptCacheIsIgnoredAndRebuilt() {
        UUID user = createUser();
        UUID favourite = game("Corrupt taste").mechanics(m("Area")).insert();
        collect(user, favourite, false, true, 0);
        game("Area game").mechanics(m("Area")).insert();
        redis.opsForValue().set("rec:" + user, "{not json");

        assertThat(titles(recommendationService.getRecommended(user, PageRequest.of(0, 5)))).containsExactly("Area game");
        assertThat(redis.opsForValue().get("rec:" + user)).startsWith("[");
    }
}
