package com.meeplehearth.match.service;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.time.temporal.ChronoUnit;

import static org.assertj.core.api.Assertions.assertThat;

/** Event defaults derived from a match group when it is accepted. */
class MatchServiceAcceptDefaultsTest {

    private final Instant now = Instant.parse("2026-10-05T10:20:00Z");

    @Test
    void titleIsGameNameNightTrimmedToTheEventLimit() {
        assertThat(MatchService.eventTitle("Catan")).isEqualTo("Catan Night");
        assertThat(MatchService.eventTitle("  ")).isEqualTo("Game Night");
        assertThat(MatchService.eventTitle(null)).isEqualTo("Game Night");
        assertThat(MatchService.eventTitle("x".repeat(120))).hasSize(100);
    }

    @Test
    void startIsTheOverlapWhenAheadOtherwiseAUsefulSlot() {
        Instant ahead = now.plus(3, ChronoUnit.HOURS);
        assertThat(MatchService.suggestedStart(ahead, now)).isEqualTo(ahead);
        assertThat(MatchService.suggestedStart(null, now)).isEqualTo(now.plus(1, ChronoUnit.DAYS));
        assertThat(MatchService.suggestedStart(now.minus(1, ChronoUnit.HOURS), now))
                .isEqualTo(Instant.parse("2026-10-05T12:00:00Z"));
    }

    @Test
    void capacityIsGameMaxWithinGroupSizeAndEventLimits() {
        assertThat(MatchService.eventCapacity(null, 2)).isEqualTo(8);
        assertThat(MatchService.eventCapacity(5, 2)).isEqualTo(5);
        assertThat(MatchService.eventCapacity(1, 1)).isEqualTo(2);
        assertThat(MatchService.eventCapacity(4, 6)).isEqualTo(6);
        assertThat(MatchService.eventCapacity(99, 3)).isEqualTo(50);
    }
}
