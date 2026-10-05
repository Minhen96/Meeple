package com.meeplehearth.game.client;

import com.meeplehearth.support.ai.Fixtures;
import okhttp3.mockwebserver.Dispatcher;
import okhttp3.mockwebserver.MockResponse;
import okhttp3.mockwebserver.MockWebServer;
import okhttp3.mockwebserver.RecordedRequest;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.client.RestClient;

import java.io.IOException;
import java.math.BigDecimal;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Per-id batch fetching and geekitem parsing of the BGG JSON client, with the hardcoded
 * api.geekdo.com host redirected to a MockWebServer serving a captured Catan payload.
 */
class BggApiClientHttpTest {

    private MockWebServer server;
    private BggApiClient client;
    private final Map<String, MockResponse> byObjectId = new ConcurrentHashMap<>();

    @BeforeEach
    void setUp() throws IOException {
        server = new MockWebServer();
        server.setDispatcher(new Dispatcher() {
            @Override
            public MockResponse dispatch(RecordedRequest request) {
                String id = request.getRequestUrl().queryParameter("objectid");
                return byObjectId.getOrDefault(id, new MockResponse().setResponseCode(404));
            }
        });
        server.start();
        client = new BggApiClient();
        ReflectionTestUtils.setField(client, "restClient",
                RestClient.builder().baseUrl("http://localhost:" + server.getPort()).build());
    }

    @AfterEach
    void tearDown() throws IOException {
        server.shutdown();
    }

    private static MockResponse json(String body) {
        return new MockResponse().setHeader("Content-Type", "application/json").setBody(body);
    }

    @Test
    void batchSeparatesFoundNotFoundAndFailedIds() throws Exception {
        byObjectId.put("13", json(Fixtures.read("game/bgg-geekitem-catan.json")));
        byObjectId.put("14", json("{\"item\":null}"));
        byObjectId.put("16", new MockResponse().setResponseCode(500));
        byObjectId.put("17", new MockResponse().setBody("<html>Just a moment...</html>"));

        BggApiClient.BggBatchResult result = client.fetchDetails(Arrays.asList(13L, 14L, null, 15L, 16L, 17L));

        assertThat(result.details()).extracting(BggApiClient.BggGameDetail::bggId).containsExactly(13L);
        assertThat(result.returned()).containsExactly(13L);
        assertThat(result.notFound()).containsExactlyInAnyOrder(14L, 15L);
        assertThat(result.failed()).containsExactlyInAnyOrder(16L, 17L);
        assertThat(result.resolved()).containsExactlyInAnyOrder(13L, 14L, 15L);

        RecordedRequest first = server.takeRequest();
        assertThat(first.getPath()).isEqualTo("/api/geekitems?nosession=1&objecttype=thing&objectid=13");
    }

    @Test
    void wholeBatchFailingThrowsSoTheBreakerRecordsIt() {
        byObjectId.put("1", new MockResponse().setResponseCode(503));
        byObjectId.put("2", new MockResponse().setResponseCode(429));

        assertThatThrownBy(() -> client.fetchDetails(List.of(1L, 2L)))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("All 2 BGG requests in batch failed");
    }

    @Test
    void emptyAndNullOnlyBatchesNeverCallBgg() {
        assertThat(client.fetchDetails(List.of()).details()).isEmpty();
        assertThat(client.fetchDetails(null).details()).isEmpty();
        assertThat(client.fetchDetails(Arrays.asList((Long) null)).resolved()).isEmpty();
        assertThat(server.getRequestCount()).isZero();
    }

    @Test
    void singleDetailLookup() {
        byObjectId.put("13", json(Fixtures.read("game/bgg-geekitem-catan.json")));

        assertThat(client.getDetail(13L)).hasValueSatisfying(d -> assertThat(d.title()).isEqualTo("CATAN"));
        assertThat(client.getDetail(99L)).isEmpty();
        assertThat(client.getDetails(List.of(13L))).hasSize(1);
        assertThat(client.search("catan")).isEmpty();
    }

    @Test
    void geekItemFieldsAreMapped() {
        BggApiClient.BggGameDetail d = client.parseGeekItem(Fixtures.read("game/bgg-geekitem-catan.json")).orElseThrow();

        assertThat(d.bggId()).isEqualTo(13L);
        assertThat(d.title()).isEqualTo("CATAN");
        assertThat(d.thumbnailUrl()).isEqualTo("https://cf.geekdo-images.com/previewthumb.jpg");
        assertThat(d.imageUrl()).isEqualTo("https://cf.geekdo-images.com/original.jpg");
        assertThat(d.description()).isEqualTo("In CATAN, players try to be the dominant force on the island.");
        assertThat(d.yearPublished()).isEqualTo(1995);
        assertThat(d.minPlayers()).isEqualTo(3);
        assertThat(d.maxPlayers()).isEqualTo(4);
        assertThat(d.minPlaytime()).isEqualTo(60);
        assertThat(d.maxPlaytime()).isEqualTo(120);
        assertThat(d.mechanics()).containsExactly("Dice Rolling", "Trading");
        assertThat(d.categories()).containsExactly("Negotiation");
        assertThat(d.subdomains()).containsExactly("Strategy Games", "Family Games");
        assertThat(d.designers()).containsExactly("Klaus Teuber");
        assertThat(d.artists()).containsExactly("Michael Menzel");
        assertThat(d.publishers()).containsExactly("KOSMOS");
        assertThat(d.honors()).containsExactly("1995 Spiel des Jahres Winner");
        assertThat(d.expansions()).containsExactly("325");
        assertThat(d.subtype()).isEqualTo("boardgame");
        assertThat(d.bggUrl()).isEqualTo("/boardgame/13/catan");
        assertThat(d.bggRating()).isNull();
        assertThat(d.complexityWeight()).isNull();
    }

    @Test
    void imageFallbacksAndLooseNumbers() {
        BggApiClient.BggGameDetail thumbOnly = client.parseGeekItem("""
                {"item":{"objectid":"5","images":{"thumb":"t.png"},"imageurl":"",
                 "minplayers":2,"maxplayers":"x","yearpublished":"","description":"<p> </p>","links":{"boardgamemechanic":{}}}}
                """).orElseThrow();
        assertThat(thumbOnly.thumbnailUrl()).isEqualTo("t.png");
        assertThat(thumbOnly.imageUrl()).as("falls back to the thumbnail").isEqualTo("t.png");
        assertThat(thumbOnly.minPlayers()).as("numeric JSON is not accepted, only strings").isNull();
        assertThat(thumbOnly.maxPlayers()).isNull();
        assertThat(thumbOnly.yearPublished()).isNull();
        assertThat(thumbOnly.description()).isNull();
        assertThat(thumbOnly.mechanics()).isEmpty();

        BggApiClient.BggGameDetail legacy = client.parseGeekItem("""
                {"item":{"objectid":"6","images":{"square200":"s.png"},"imageurl":"legacy.png"}}
                """).orElseThrow();
        assertThat(legacy.thumbnailUrl()).isEqualTo("s.png");
        assertThat(legacy.imageUrl()).isEqualTo("legacy.png");

        assertThat(client.parseGeekItem("{\"item\":{\"name\":\"no id\"}}")).isEmpty();
        assertThatThrownBy(() -> client.parseGeekItem("{\"item\":{\"objectid\":\"abc\"}}"))
                .isInstanceOf(BggApiClient.BggResponseException.class)
                .hasMessageContaining("Failed to parse BGG geekitem");
    }

    @Test
    void detailRecordCarriesRatingFields() {
        var d = new BggApiClient.BggGameDetail(1L, "t", null, null, null, null, null, null, null, null,
                new BigDecimal("7.5"), new BigDecimal("2.3"), null, null, null, null, null, null, null, null, null, null);
        assertThat(d.bggRating()).isEqualByComparingTo("7.5");
        assertThat(new BggApiClient.BggSearchResult(1L, "Catan", 1995).title()).isEqualTo("Catan");
    }
}
