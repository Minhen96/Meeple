package com.meeplehearth.match;

import com.meeplehearth.match.entity.MatchRequest;
import org.junit.jupiter.api.Test;

import java.time.Instant;

import static org.assertj.core.api.Assertions.assertThat;

class MatchRequestOverlapTest {

    private static final Instant T0 = Instant.parse("2026-10-10T10:00:00Z");

    private static MatchRequest window(Integer fromHour, Integer toHour) {
        MatchRequest mr = new MatchRequest();
        mr.setAvailableFrom(fromHour == null ? null : T0.plusSeconds(fromHour * 3600L));
        mr.setAvailableTo(toHour == null ? null : T0.plusSeconds(toHour * 3600L));
        return mr;
    }

    @Test
    void anyMissingBoundMeansNoTimeConstraint() {
        MatchRequest bounded = window(0, 1);
        assertThat(window(null, 5).overlapsWith(bounded)).isTrue();
        assertThat(window(5, null).overlapsWith(bounded)).isTrue();
        assertThat(bounded.overlapsWith(window(null, 9))).isTrue();
        assertThat(bounded.overlapsWith(window(9, null))).isTrue();
    }

    @Test
    void boundedWindowsOverlapOnlyWhenTheyIntersect() {
        assertThat(window(0, 3).overlapsWith(window(2, 5))).isTrue();
        assertThat(window(2, 5).overlapsWith(window(0, 3))).isTrue();
        assertThat(window(0, 10).overlapsWith(window(2, 3))).isTrue();
        // Touching end-to-start is not an overlap; disjoint either way round is not either
        assertThat(window(0, 2).overlapsWith(window(2, 4))).isFalse();
        assertThat(window(4, 6).overlapsWith(window(0, 2))).isFalse();
        assertThat(window(0, 2).overlapsWith(window(4, 6))).isFalse();
    }
}
