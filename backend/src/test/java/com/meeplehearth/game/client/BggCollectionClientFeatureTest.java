package com.meeplehearth.game.client;

import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import io.github.resilience4j.circuitbreaker.CircuitBreakerConfig;
import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class BggCollectionClientFeatureTest {

    private FakeBggServer server;
    private CircuitBreakerRegistry registry;

    @BeforeEach
    void setUp() throws Exception {
        server = new FakeBggServer();
        registry = CircuitBreakerRegistry.of(CircuitBreakerConfig.custom()
                .slidingWindowSize(2).minimumNumberOfCalls(2).failureRateThreshold(50).build());
    }

    @AfterEach
    void tearDown() {
        server.close();
    }

    private BggCollectionClient client(String token, int maxRetries) {
        return new BggCollectionClient(server.baseUrl(), token, 1, maxRetries, registry);
    }

    @Test
    void retriesWhileQueuedThenParsesTheCollection() {
        server.enqueue(202, FakeBggServer.QUEUED).enqueue(429, "").enqueue(200,
                FakeBggServer.collection(13, "Catan", 822, "Carcassonne"));

        List<BggCollectionClient.CollectionItem> items = client("secret", 10).fetchOwnedCollection("alice b");

        assertThat(items).extracting(BggCollectionClient.CollectionItem::bggId).containsExactly(13L, 822L);
        BggCollectionClient.CollectionItem catan = items.get(0);
        assertThat(catan.name()).isEqualTo("Catan");
        assertThat(catan.subtype()).isEqualTo("boardgame");
        assertThat(catan.yearPublished()).isEqualTo(2015);
        assertThat(catan.thumbnailUrl()).isEqualTo("https://cf.geekdo-images.com/t13.jpg");
        assertThat(catan.imageUrl()).isEqualTo("https://cf.geekdo-images.com/13.jpg");

        assertThat(server.requests()).hasSize(3);
        FakeBggServer.Request request = server.requests().get(0);
        assertThat(request.authorization()).isEqualTo("Bearer secret");
        assertThat(request.query()).contains("username=alice%20b", "own=1", "excludesubtype=boardgameexpansion");
        assertThat(registry.circuitBreaker("bgg").getMetrics().getNumberOfSuccessfulCalls()).isEqualTo(1);
    }

    @Test
    void givesUpAfterMaxRetries() {
        for (int i = 0; i < 4; i++) server.enqueue(202, FakeBggServer.QUEUED);

        assertThatThrownBy(() -> client("secret", 3).fetchOwnedCollection("alice"))
                .isInstanceOf(BggApiClient.BggUnavailableException.class);
        assertThat(server.requests()).hasSize(4);
        assertThat(registry.circuitBreaker("bgg").getMetrics().getNumberOfFailedCalls()).isEqualTo(1);
    }

    @Test
    void unknownUserIsNotABreakerFailure() {
        server.enqueue(200, FakeBggServer.INVALID_USER).enqueue(404, "");
        BggCollectionClient client = client("secret", 0);

        assertThatThrownBy(() -> client.fetchOwnedCollection("ghost"))
                .isInstanceOf(BggCollectionClient.BggUserNotFoundException.class);
        assertThatThrownBy(() -> client.fetchOwnedCollection("ghost"))
                .isInstanceOf(BggCollectionClient.BggUserNotFoundException.class);
        assertThat(registry.circuitBreaker("bgg").getMetrics().getNumberOfFailedCalls()).isZero();
        assertThat(registry.circuitBreaker("bgg").getState()).isEqualTo(CircuitBreaker.State.CLOSED);
    }

    @Test
    void failuresOpenTheBreakerAndThenCallsAreRejectedWithoutHttp() {
        server.enqueue(500, "oops").enqueue(401, "");
        BggCollectionClient client = client("secret", 0);

        assertThatThrownBy(() -> client.fetchOwnedCollection("a")).isInstanceOf(BggApiClient.BggUnavailableException.class);
        assertThatThrownBy(() -> client.fetchOwnedCollection("a")).isInstanceOf(BggApiClient.BggUnavailableException.class);
        assertThat(registry.circuitBreaker("bgg").getState()).isEqualTo(CircuitBreaker.State.OPEN);

        assertThatThrownBy(() -> client.fetchOwnedCollection("a"))
                .isInstanceOf(BggApiClient.BggUnavailableException.class)
                .hasMessageContaining("circuit breaker");
        assertThat(server.requests()).hasSize(2);
    }

    @Test
    void withoutTokenNothingIsCalled() {
        BggCollectionClient client = client("  ", 3);
        assertThat(client.isConfigured()).isFalse();
        assertThatThrownBy(() -> client.fetchOwnedCollection("a")).isInstanceOf(BggApiClient.BggUnavailableException.class);
        assertThat(server.requests()).isEmpty();
    }

    @Test
    void parsingRejectsGarbageAndOddDocuments() {
        assertThatThrownBy(() -> BggCollectionClient.parseCollection("", "u"))
                .isInstanceOf(BggApiClient.BggUnavailableException.class);
        assertThatThrownBy(() -> BggCollectionClient.parseCollection("<html><body>challenge", "u"))
                .isInstanceOf(BggApiClient.BggUnavailableException.class);
        assertThatThrownBy(() -> BggCollectionClient.parseCollection(FakeBggServer.QUEUED, "u"))
                .isInstanceOf(BggApiClient.BggUnavailableException.class);
        assertThatThrownBy(() -> BggCollectionClient.parseCollection("<errors><error><message>Rate limited</message></error></errors>", "u"))
                .isInstanceOf(BggApiClient.BggUnavailableException.class);
        assertThatThrownBy(() -> BggCollectionClient.parseCollection("<other/>", "u"))
                .isInstanceOf(BggApiClient.BggUnavailableException.class);
        // XXE: a DOCTYPE is refused outright
        assertThatThrownBy(() -> BggCollectionClient.parseCollection(
                "<?xml version=\"1.0\"?><!DOCTYPE items [<!ENTITY x SYSTEM \"file:///etc/passwd\">]><items>&x;</items>", "u"))
                .isInstanceOf(BggApiClient.BggUnavailableException.class);
    }

    @Test
    void parsingToleratesMalformedItems() {
        List<BggCollectionClient.CollectionItem> items = BggCollectionClient.parseCollection(
                "<items><item objectid=\"x\"><name> </name><yearpublished>abc</yearpublished></item>"
                        + "<item objectid=\"7\" subtype=\"boardgame\"><name>Seven</name>"
                        + "<thumbnail>https://img/7.png</thumbnail></item></items>", "u");
        assertThat(items).hasSize(2);
        assertThat(items.get(0).bggId()).isNull();
        assertThat(items.get(0).name()).isNull();
        assertThat(items.get(0).yearPublished()).isNull();
        assertThat(items.get(1).thumbnailUrl()).isEqualTo("https://img/7.png");
        assertThat(BggCollectionClient.normalizeUrl(null)).isNull();
    }
}
