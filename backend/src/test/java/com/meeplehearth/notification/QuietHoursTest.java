package com.meeplehearth.notification;

import com.meeplehearth.notification.service.QuietHours;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.time.LocalTime;
import java.time.ZoneId;

import static org.assertj.core.api.Assertions.assertThat;

class QuietHoursTest {

    private static final ZoneId UTC = QuietHours.UTC;

    private static Instant utc(String time) {
        return Instant.parse("2026-10-05T" + time + ":00Z");
    }

    @Test
    void sameDayWindowIncludesStartExcludesEnd() {
        QuietHours q = new QuietHours(true, LocalTime.of(13, 0), LocalTime.of(15, 0), UTC);
        assertThat(q.isActive(utc("12:59"))).isFalse();
        assertThat(q.isActive(utc("13:00"))).isTrue();
        assertThat(q.isActive(utc("14:30"))).isTrue();
        assertThat(q.isActive(utc("15:00"))).isFalse();
    }

    @Test
    void overnightWindowWrapsMidnight() {
        QuietHours q = new QuietHours(true, LocalTime.of(22, 0), LocalTime.of(8, 0), UTC);
        assertThat(q.isActive(utc("23:30"))).isTrue();
        assertThat(q.isActive(utc("02:00"))).isTrue();
        assertThat(q.isActive(utc("08:00"))).isFalse();
        assertThat(q.isActive(utc("12:00"))).isFalse();
        assertThat(q.isActive(utc("22:00"))).isTrue();
    }

    @Test
    void evaluatesInTheUsersTimezone() {
        // 15:00 UTC is 23:00 in Shanghai
        QuietHours q = new QuietHours(true, LocalTime.of(22, 0), LocalTime.of(7, 0), ZoneId.of("Asia/Shanghai"));
        assertThat(q.isActive(utc("15:00"))).isTrue();
        assertThat(q.isActive(utc("05:00"))).isFalse();
    }

    @Test
    void disabledIncompleteOrEmptyWindowsAreNeverActive() {
        assertThat(QuietHours.NONE.isActive(utc("03:00"))).isFalse();
        assertThat(new QuietHours(false, LocalTime.of(0, 0), LocalTime.of(23, 0), UTC).isActive(utc("03:00"))).isFalse();
        assertThat(new QuietHours(true, null, LocalTime.of(23, 0), UTC).isActive(utc("03:00"))).isFalse();
        assertThat(new QuietHours(true, LocalTime.of(3, 0), LocalTime.of(3, 0), UTC).isActive(utc("03:00"))).isFalse();
    }

    @Test
    void unknownOrBlankZonesFallBackToUtc() {
        assertThat(QuietHours.zoneOrUtc(null).getId()).isEqualTo("UTC");
        assertThat(QuietHours.zoneOrUtc(" ").getId()).isEqualTo("UTC");
        assertThat(QuietHours.zoneOrUtc("Mars/Base").getId()).isEqualTo("UTC");
        assertThat(QuietHours.zoneOrUtc(" Europe/Paris ").getId()).isEqualTo("Europe/Paris");
    }
}
