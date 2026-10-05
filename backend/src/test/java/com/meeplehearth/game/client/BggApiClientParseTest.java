package com.meeplehearth.game.client;

import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class BggApiClientParseTest {

    private final BggApiClient client = new BggApiClient();

    @Test
    void validItemIsParsed() {
        var detail = client.parseGeekItem("""
                {"item":{"objectid":"13","name":"Catan","minplayers":"3","maxplayers":"4","images":{"thumb":"//t.png"}}}
                """);
        assertThat(detail).isPresent();
        assertThat(detail.get().bggId()).isEqualTo(13L);
        assertThat(detail.get().minPlayers()).isEqualTo(3);
    }

    @Test
    void jsonWithoutItemMeansNoData() {
        assertThat(client.parseGeekItem("{}")).isEmpty();
        assertThat(client.parseGeekItem("{\"item\":null}")).isEmpty();
    }

    @Test
    void nonJsonOrEmptyBodiesAreFailures() {
        for (String body : new String[]{"<html>Just a moment...</html>", "", "[1,2]"}) {
            assertThatThrownBy(() -> client.parseGeekItem(body))
                    .as(body)
                    .isInstanceOf(BggApiClient.BggResponseException.class);
        }
        assertThatThrownBy(() -> client.parseGeekItem(null)).isInstanceOf(BggApiClient.BggResponseException.class);
    }

    @Test
    void resolvedCombinesReturnedAndNotFound() {
        var result = new BggApiClient.BggBatchResult(List.of(), Set.of(1L), Set.of(2L), Set.of(3L));
        assertThat(result.resolved()).containsExactlyInAnyOrder(1L, 2L);
    }
}
