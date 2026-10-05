package com.meeplehearth.user;

import com.meeplehearth.user.dto.UserSummary;
import com.meeplehearth.user.entity.User;
import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class AccountPolicyFeatureTest {

    private static final Instant NOW = Instant.parse("2026-10-05T12:00:00Z");

    @Test
    void deletionGraceIsThirtyDays() {
        assertThat(AccountPolicy.withinDeletionGrace(NOW.minus(Duration.ofDays(29)), NOW)).isTrue();
        assertThat(AccountPolicy.withinDeletionGrace(NOW.minus(Duration.ofDays(30)), NOW)).isFalse();
        assertThat(AccountPolicy.withinDeletionGrace(null, NOW)).isFalse();
    }

    @Test
    void usernameCooldown() {
        assertThat(AccountPolicy.usernameChangeAvailableAt(null, NOW)).isNull();
        assertThat(AccountPolicy.usernameChangeAvailableAt(NOW.minus(Duration.ofDays(31)), NOW)).isNull();
        assertThat(AccountPolicy.usernameChangeAvailableAt(NOW.minus(Duration.ofDays(1)), NOW))
                .isEqualTo(NOW.plus(Duration.ofDays(29)));
    }

    @Test
    void summaryHidesDeletedUsers() {
        User user = new User();
        user.setId(UUID.randomUUID());
        user.setUsername("ana");
        user.setDisplayName("Ana");
        user.setAvatarUrl("https://cdn/a.webp");
        assertThat(UserSummary.from(user)).isEqualTo(
                new UserSummary(user.getId(), "ana", "Ana", "https://cdn/a.webp", false));
        user.setDeletedAt(NOW);
        assertThat(UserSummary.from(user)).isEqualTo(new UserSummary(user.getId(), null, null, null, true));
        assertThat(UserSummary.from(null)).isNull();
    }
}
