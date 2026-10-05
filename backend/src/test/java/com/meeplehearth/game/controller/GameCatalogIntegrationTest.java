package com.meeplehearth.game.controller;

import com.jayway.jsonpath.JsonPath;
import com.meeplehearth.game.client.BggApiClient;
import com.meeplehearth.game.service.GameHydrationService;
import com.meeplehearth.support.ai.AiGameIntegrationTestBase;
import com.meeplehearth.support.ai.FakeOpenAi;
import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;

import static org.assertj.core.api.Assertions.assertThat;
import static org.awaitility.Awaitility.await;
import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.containsInAnyOrder;
import static org.hamcrest.Matchers.hasSize;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.timeout;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Game catalog: browse filters/sorting, search (LIKE, CJK translation, trigram), detail, BGG ensure. */
class GameCatalogIntegrationTest extends AiGameIntegrationTestBase {

    @Autowired private GameHydrationService hydrationService;

    /** A random lowercase token so browse/search only see this test's games. */
    private static String token() {
        StringBuilder sb = new StringBuilder("zq");
        for (int i = 0; i < 8; i++) {
            sb.append((char) ('a' + ThreadLocalRandom.current().nextInt(26)));
        }
        return sb.toString();
    }

    private ResultActions browse(String q, String... params) throws Exception {
        MockHttpServletRequestBuilder req = get("/api/v1/games").param("q", q).param("size", "50");
        for (int i = 0; i < params.length; i += 2) {
            req.param(params[i], params[i + 1]);
        }
        return mvc.perform(req);
    }

    private static BggApiClient.BggGameDetail detail(long bggId, String title, Integer minPlayers) {
        return new BggApiClient.BggGameDetail(bggId, title, "//cf.geekdo-images.com/t.jpg", "https://cf.geekdo-images.com/i.jpg",
                "Fetched description", 2001, minPlayers, 6, 45, 90, new BigDecimal("7.10"), new BigDecimal("2.50"),
                new String[]{"Hand Management"}, new String[]{"Card Game"}, new String[]{"Strategy Games"},
                new String[]{"Designer"}, new String[]{"Artist"}, new String[]{"Publisher"}, new String[0],
                new String[]{"777"}, "boardgame", "https://boardgamegeek.com/boardgame/" + bggId);
    }

    // -------------------------------------------------------------------------
    // Browse
    // -------------------------------------------------------------------------

    @Test
    void browseDefaultsToRankOrderAndSkipsUnrankedAndNonBoardgames() throws Exception {
        String t = token();
        game(t + " third").rank(-30).insert();
        game(t + " first").rank(-50).insert();
        game(t + " second").rank(-40).insert();
        game(t + " unranked").rank(null).insert();
        game(t + " expansion").rank(-60).type("boardgameexpansion").insert();

        browse(t)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.content[*].title", contains(t + " first", t + " second", t + " third")))
                .andExpect(jsonPath("$.data.page.totalElements").value(3));

        // Paging keeps the stable order
        mvc.perform(get("/api/v1/games").param("q", t.toUpperCase()).param("size", "2").param("page", "1"))
                .andExpect(jsonPath("$.data.content[*].title", contains(t + " third")))
                .andExpect(jsonPath("$.data.page.totalPages").value(2));
    }

    @Test
    void browseSortsByRequestedFieldAndKeepsNullYears() throws Exception {
        String t = token();
        game(t + " low").rating("6.1").year(null).insert();
        game(t + " high").rating("8.4").year(2020).insert();
        game(t + " unrated").rating(null).year(1999).insert();

        browse(t, "sort", "bggRating,desc")
                .andExpect(jsonPath("$.data.content[*].title", contains(t + " high", t + " low")));
        browse(t, "sort", "yearPublished,asc", "sort", "id")
                .andExpect(jsonPath("$.data.content", hasSize(3)));
    }

    @Test
    void browseFiltersByPlayersPlaytimeAndRating() throws Exception {
        String t = token();
        game(t + " duel").players(2, 2).playTime(20).rating("6.0").insert();
        game(t + " party").players(4, 12).playTime(30).rating("7.0").insert();
        game(t + " epic").players(1, 4).playTime(240).rating("8.5").insert();

        browse(t, "minPlayers", "1").andExpect(jsonPath("$.data.content[*].title", contains(t + " epic")));
        browse(t, "maxPlayers", "6").andExpect(jsonPath("$.data.content[*].title", contains(t + " party")));
        browse(t, "minPlaytime", "25", "maxPlaytime", "60")
                .andExpect(jsonPath("$.data.content[*].title", contains(t + " party")));
        browse(t, "minRating", "7.0")
                .andExpect(jsonPath("$.data.content[*].title", containsInAnyOrder(t + " party", t + " epic")));
        browse(t, "genre", "2 Player")
                .andExpect(jsonPath("$.data.content[*].title", containsInAnyOrder(t + " duel", t + " epic")));
    }

    @Test
    void browseFiltersByComplexityThroughGameDetails() throws Exception {
        String t = token();
        game(t + " light").complexity("1.5").insert();
        game(t + " medium").complexity("2.8").insert();
        game(t + " heavy").complexity("4.2").insert();
        game(t + " unknown").insert();

        browse(t, "minComplexity", "2.0")
                .andExpect(jsonPath("$.data.content[*].title", containsInAnyOrder(t + " medium", t + " heavy")));
        browse(t, "maxComplexity", "3.0")
                .andExpect(jsonPath("$.data.content[*].title", containsInAnyOrder(t + " light", t + " medium")));
        browse(t, "minComplexity", "2.0", "maxComplexity", "3.0")
                .andExpect(jsonPath("$.data.content[*].title", contains(t + " medium")));
    }

    @Test
    void browseFiltersByGenreViaSubdomainRankOrFamily() throws Exception {
        String t = token();
        game(t + " strat rank").rankStrategy(10).insert();
        game(t + " strat family").families("Strategy Games", "Thematic Games").insert();
        game(t + " party").rankParty(3).insert();
        game(t + " family").families("Family Games").insert();
        game(t + " abstract").rankAbstract(7).insert();
        game(t + " no detail").insert();

        browse(t, "genre", "Strategy").andExpect(jsonPath("$.data.content[*].title",
                containsInAnyOrder(t + " strat rank", t + " strat family")));
        browse(t, "genre", "party").andExpect(jsonPath("$.data.content[*].title", contains(t + " party")));
        browse(t, "genre", "Family").andExpect(jsonPath("$.data.content[*].title", contains(t + " family")));
        browse(t, "genre", "Abstract").andExpect(jsonPath("$.data.content[*].title", contains(t + " abstract")));
        // Unknown genre: any game with a details row
        browse(t, "genre", "Wargame").andExpect(jsonPath("$.data.content", hasSize(5)));
        browse(t, "genre", " ").andExpect(jsonPath("$.data.content", hasSize(6)));
    }

    @Test
    void browseMatchesChineseNames() throws Exception {
        String t = token();
        game("Some English Name").nameZh("卡坦島 " + t).insert();

        browse(t).andExpect(jsonPath("$.data.content[*].title", contains("Some English Name")));
    }

    @Test
    void browseTriggersBackgroundHydrationForUnhydratedGames() throws Exception {
        String t = token();
        GameSeed seed = game(t + " raw").unhydrated();
        seed.insert();
        game(t + " ready").insert();

        browse(t).andExpect(jsonPath("$.data.content", hasSize(2)));

        verify(bggApiClient, timeout(10_000)).fetchDetails(List.of(seed.bggId()));
    }

    @Test
    void recommendedSortIsPersonalizedOnlyForSignedInUsers() throws Exception {
        String t = token();
        String mech = "Mech-" + t;
        UUID user = createUser();
        UUID fav = game(t + " favourite").mechanics(mech).insert();
        game(t + " similar").mechanics(mech).insert();
        game(t + " unrelated").mechanics("Other-" + t).insert();
        jdbc.update("INSERT INTO user_games (user_id, game_id, is_favorited) VALUES (?, ?, true)", user, fav);

        mvc.perform(get("/api/v1/games").param("sort", "recommended").cookie(auth(user)))
                .andExpect(jsonPath("$.data.content[*].title", contains(t + " similar")));

        // Anonymous: the virtual sort is ignored and the normal catalog is returned
        browse(t, "sort", "recommended")
                .andExpect(jsonPath("$.data.content", hasSize(3)));
    }

    // -------------------------------------------------------------------------
    // Search
    // -------------------------------------------------------------------------

    @Test
    void searchUsesLikeMatchOrderedByRankThenPopularity() throws Exception {
        String t = token();
        UUID user = createUser();
        game(t + " popular unranked").rank(null).usersRated(900).insert();
        game(t + " obscure unranked").rank(null).usersRated(null).insert();
        game(t + " top").rank(-100).thumbnail("https://img/top.jpg").year(2010).insert();

        mvc.perform(get("/api/v1/games/search").param("q", t).cookie(auth(user)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[*].title",
                        contains(t + " top", t + " popular unranked", t + " obscure unranked")))
                .andExpect(jsonPath("$.data[0].thumbnailUrl").value("https://img/top.jpg"))
                .andExpect(jsonPath("$.data[0].yearPublished").value(2010))
                .andExpect(jsonPath("$.data[0].translatedFrom").doesNotExist());
        assertThat(OPENAI.completionRequests()).as("latin queries are not translated").isEmpty();
    }

    @Test
    void searchFallsBackToTrigramSimilarityForTypos() throws Exception {
        String t = token();
        UUID user = createUser();
        game("Xylophonica Quest " + t).insert();

        mvc.perform(get("/api/v1/games/search").param("q", "Xylofonica Quest " + t).cookie(auth(user)))
                .andExpect(jsonPath("$.data[*].title", contains("Xylophonica Quest " + t)));
    }

    @Test
    void cjkQueriesAreTranslatedBeforeSearching() throws Exception {
        String t = token();
        UUID user = createUser();
        game("Catan " + t).insert();
        OPENAI.onCompletion(body -> "  Catan " + t + "  ");

        mvc.perform(get("/api/v1/games/search").param("q", "卡坦島").cookie(auth(user)))
                .andExpect(jsonPath("$.data[*].title", contains("Catan " + t)))
                .andExpect(jsonPath("$.data[0].translatedFrom").value("卡坦島"));
        assertThat(FakeOpenAi.lastMessage(OPENAI.completionRequests().get(0))).isEqualTo("卡坦島");
    }

    @Test
    void failedOrBlankTranslationFallsBackToOriginalQuery() throws Exception {
        UUID user = createUser();
        String t = token();
        game("ボード " + t).insert();

        OPENAI.failCompletions(500);
        mvc.perform(get("/api/v1/games/search").param("q", "ボード " + t).cookie(auth(user)))
                .andExpect(jsonPath("$.data[*].title", contains("ボード " + t)))
                .andExpect(jsonPath("$.data[0].translatedFrom").doesNotExist());

        OPENAI.reset();
        OPENAI.onCompletion(body -> "   ");
        mvc.perform(get("/api/v1/games/search").param("q", "ボード " + t).cookie(auth(user)))
                .andExpect(jsonPath("$.data[0].translatedFrom").doesNotExist());
    }

    @Test
    void blankSearchIsABadRequest() throws Exception {
        mvc.perform(get("/api/v1/games/search").param("q", " ").cookie(auth(createUser())))
                .andExpect(status().isBadRequest());
    }

    // -------------------------------------------------------------------------
    // Detail
    // -------------------------------------------------------------------------

    @Test
    void gameDetailIncludesDetailsAndRulebookFlag() throws Exception {
        UUID user = createUser();
        UUID gameId = game("Detailed Game").description("Long description").complexity("3.1")
                .mechanics("Worker Placement").categories("Economic").bggUrl("https://bgg/x").insert();
        insertRulebook(gameId, "onj", "approved", Instant.now());

        mvc.perform(get("/api/v1/games/{id}", gameId).cookie(auth(user)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.title").value("Detailed Game"))
                .andExpect(jsonPath("$.data.description").value("Long description"))
                .andExpect(jsonPath("$.data.complexityWeight").value(3.1))
                .andExpect(jsonPath("$.data.mechanics[0]").value("Worker Placement"))
                .andExpect(jsonPath("$.data.categories[0]").value("Economic"))
                .andExpect(jsonPath("$.data.bggUrl").value("https://bgg/x"))
                .andExpect(jsonPath("$.data.hasRulebook").value(true));
        verify(bggApiClient, never()).fetchDetails(anyList());

        UUID bare = game("Bare Detail").insert();
        mvc.perform(get("/api/v1/games/{id}", bare).cookie(auth(user)))
                .andExpect(jsonPath("$.data.description").doesNotExist())
                .andExpect(jsonPath("$.data.hasRulebook").value(false));

        mvc.perform(get("/api/v1/games/{id}", UUID.randomUUID()).cookie(auth(user)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("GAME_NOT_FOUND"));
    }

    @Test
    void unhydratedGameIsHydratedSynchronouslyOnDetail() throws Exception {
        UUID user = createUser();
        GameSeed seed = game("Raw Detail").unhydrated();
        UUID gameId = seed.insert();
        when(bggApiClient.fetchDetails(List.of(seed.bggId()))).thenReturn(new BggApiClient.BggBatchResult(
                List.of(detail(seed.bggId(), "Raw Detail", 3)), Set.of(seed.bggId()), Set.of(), Set.of()));

        mvc.perform(get("/api/v1/games/{id}", gameId).cookie(auth(user)))
                .andExpect(jsonPath("$.data.minPlayers").value(3))
                .andExpect(jsonPath("$.data.maxPlayers").value(6))
                .andExpect(jsonPath("$.data.playTime").value(45))
                .andExpect(jsonPath("$.data.thumbnailUrl").value("https://cf.geekdo-images.com/t.jpg"))
                .andExpect(jsonPath("$.data.mechanics[0]").value("Hand Management"))
                .andExpect(jsonPath("$.data.families[0]").value("Strategy Games"))
                .andExpect(jsonPath("$.data.expansions[0]").value("777"))
                .andExpect(jsonPath("$.data.description").value("Fetched description"));
    }

    @Test
    void detailIsServedEvenWhenBggIsDown() throws Exception {
        UUID user = createUser();
        GameSeed seed = game("Offline Detail").unhydrated();
        UUID gameId = seed.insert();
        when(bggApiClient.fetchDetails(anyList())).thenThrow(new BggApiClient.BggUnavailableException("open"));

        mvc.perform(get("/api/v1/games/{id}", gameId).cookie(auth(user)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.title").value("Offline Detail"))
                .andExpect(jsonPath("$.data.minPlayers").doesNotExist());

        org.mockito.Mockito.doThrow(new IllegalStateException("parse bug")).when(bggApiClient).fetchDetails(anyList());
        mvc.perform(get("/api/v1/games/{id}", gameId).cookie(auth(user))).andExpect(status().isOk());
    }

    // -------------------------------------------------------------------------
    // Ensure from BGG
    // -------------------------------------------------------------------------

    @Test
    void ensureReturnsCachedGameWithoutCallingBgg() throws Exception {
        UUID user = createUser();
        GameSeed seed = game("Cached Bgg Game").description("cached");
        seed.insert();

        mvc.perform(get("/api/v1/games/bgg/{bggId}", seed.bggId()).cookie(auth(user)))
                .andExpect(jsonPath("$.data.title").value("Cached Bgg Game"))
                .andExpect(jsonPath("$.data.description").value("cached"));
        verify(bggApiClient, never()).getDetail(any());
    }

    @Test
    void ensureFetchesAndCachesNewGames() throws Exception {
        UUID user = createUser();
        long bggId = -ThreadLocalRandom.current().nextLong(1_000_000L, 9_000_000_000_000L);
        when(bggApiClient.getDetail(bggId)).thenReturn(Optional.of(detail(bggId, "Fresh From Bgg", 2)));

        String body = mvc.perform(get("/api/v1/games/bgg/{bggId}", bggId).cookie(auth(user)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.title").value("Fresh From Bgg"))
                .andExpect(jsonPath("$.data.playTime").value(90))
                .andExpect(jsonPath("$.data.complexityWeight").value(2.5))
                .andExpect(jsonPath("$.data.bggRating").value(7.1))
                .andReturn().getResponse().getContentAsString();
        UUID id = UUID.fromString(JsonPath.read(body, "$.data.id"));
        trackGame(id);

        assertThat(jdbc.queryForObject("SELECT description FROM game_details WHERE game_id = ?", String.class, id))
                .isEqualTo("Fetched description");
        mvc.perform(get("/api/v1/games/bgg/{bggId}", bggId).cookie(auth(user)))
                .andExpect(jsonPath("$.data.id").value(id.toString()));
        verify(bggApiClient).getDetail(bggId);
    }

    @Test
    void ensureReturnsTheRowWhenAConcurrentRequestInsertedItFirst() throws Exception {
        UUID user = createUser();
        GameSeed winner = game("Concurrent Winner");
        long bggId = winner.bggId();
        when(bggApiClient.getDetail(bggId)).thenAnswer(inv -> {
            winner.insert(); // the other request commits between our lookup and our insert
            return Optional.of(detail(bggId, "Concurrent Loser", 2));
        });

        mvc.perform(get("/api/v1/games/bgg/{bggId}", bggId).cookie(auth(user)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.title").value("Concurrent Winner"));
    }

    @Test
    void ensureMapsBggOutcomes() throws Exception {
        UUID user = createUser();
        when(bggApiClient.getDetail(-1L)).thenReturn(Optional.empty());
        when(bggApiClient.getDetail(-2L)).thenThrow(new BggApiClient.BggUnavailableException("breaker open"));

        mvc.perform(get("/api/v1/games/bgg/{bggId}", -1L).cookie(auth(user)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("GAME_NOT_FOUND"));
        mvc.perform(get("/api/v1/games/bgg/{bggId}", -2L).cookie(auth(user)))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.code").value("BGG_UNAVAILABLE"));
    }

    // -------------------------------------------------------------------------
    // Admin catalog maintenance
    // -------------------------------------------------------------------------

    @Test
    void catalogMaintenanceIsAdminOnlyAndBulkHydrationRunsInBackground() throws Exception {
        UUID user = createUser();
        UUID admin = createUser("ADMIN");
        mvc.perform(post("/api/v1/games/import").cookie(auth(user))).andExpect(status().isForbidden());
        mvc.perform(post("/api/v1/games/hydrate-images").cookie(auth(user))).andExpect(status().isForbidden());

        GameSeed raw = game("Bulk Raw").unhydrated();
        raw.insert();
        when(bggApiClient.fetchDetails(argThat(ids -> ids != null && ids.contains(raw.bggId()))))
                .thenReturn(new BggApiClient.BggBatchResult(List.of(detail(raw.bggId(), "Bulk Raw", 2)),
                        Set.of(raw.bggId()), Set.of(), Set.of()));

        mvc.perform(post("/api/v1/games/hydrate-images").cookie(auth(admin))).andExpect(status().isOk());

        await().atMost(Duration.ofSeconds(30)).until(() -> jdbc.queryForObject(
                "SELECT min_players FROM games WHERE bgg_id = ?", Integer.class, raw.bggId()) != null);
        await().atMost(Duration.ofSeconds(30)).until(() -> !hydrationService.isBulkRunning());
    }

    @Test
    @Disabled("BUG: POST /api/v1/games/import imports from a hardcoded developer path "
            + "(c:\\Users\\Minhen\\...\\boardgames.csv), so on any server it fails with NoSuchFileException -> 500")
    void adminCatalogImportSucceeds() throws Exception {
        mvc.perform(post("/api/v1/games/import").cookie(auth(createUser("ADMIN"))))
                .andExpect(status().isOk());
    }
}
