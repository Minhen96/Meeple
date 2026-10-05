package com.meeplehearth.notification.service;

import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.notification.dto.NotificationPreferenceDto;
import com.meeplehearth.notification.dto.NotificationSettingsDto;
import com.meeplehearth.notification.entity.Notification.NotificationType;
import com.meeplehearth.notification.entity.NotificationPreference;
import com.meeplehearth.notification.entity.NotificationSettings;
import com.meeplehearth.notification.repository.NotificationPreferenceRepository;
import com.meeplehearth.notification.repository.NotificationSettingsRepository;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.DateTimeException;
import java.time.Instant;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.Arrays;
import java.util.EnumMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/** Per-type delivery preferences and quiet hours (FEATURES_COMPLETE sections 7.1 and 10.1). */
@Service
public class NotificationPreferenceService {

    private final NotificationPreferenceRepository preferenceRepository;
    private final NotificationSettingsRepository settingsRepository;
    private final JdbcTemplate jdbc;

    public NotificationPreferenceService(NotificationPreferenceRepository preferenceRepository,
                                         NotificationSettingsRepository settingsRepository,
                                         JdbcTemplate jdbc) {
        this.preferenceRepository = preferenceRepository;
        this.settingsRepository = settingsRepository;
        this.jdbc = jdbc;
    }

    /** Every notification type, in enum order, with stored choices or the defaults (both on). */
    @Transactional(readOnly = true)
    public List<NotificationPreferenceDto> getPreferences(UUID userId) {
        Map<NotificationType, NotificationPreference> stored = new EnumMap<>(NotificationType.class);
        preferenceRepository.findByUserId(userId).forEach(p -> stored.put(p.getType(), p));
        return Arrays.stream(NotificationType.values())
                .map(type -> {
                    NotificationPreference p = stored.get(type);
                    return new NotificationPreferenceDto(type,
                            p == null || p.isInAppEnabled(), p == null || p.isPushEnabled());
                })
                .toList();
    }

    /** Upserts the listed types; types not listed keep their current values. */
    @Transactional
    public List<NotificationPreferenceDto> updatePreferences(UUID userId, List<NotificationPreferenceDto> updates) {
        if (updates == null) {
            throw ApiException.badRequest("VALIDATION_ERROR", "Preferences are required");
        }
        Set<NotificationType> seen = new HashSet<>();
        for (NotificationPreferenceDto dto : updates) {
            if (dto == null || dto.type() == null || dto.inAppEnabled() == null || dto.pushEnabled() == null) {
                throw ApiException.badRequest("VALIDATION_ERROR", "Each preference needs type, inAppEnabled and pushEnabled");
            }
            if (!seen.add(dto.type())) {
                throw ApiException.badRequest("VALIDATION_ERROR", "Duplicate preference type " + dto.type());
            }
        }
        Map<NotificationType, NotificationPreference> stored = new EnumMap<>(NotificationType.class);
        preferenceRepository.findByUserId(userId).forEach(p -> stored.put(p.getType(), p));
        Instant now = Instant.now();
        for (NotificationPreferenceDto dto : updates) {
            NotificationPreference p = stored.getOrDefault(dto.type(), new NotificationPreference(userId, dto.type()));
            p.setInAppEnabled(dto.inAppEnabled());
            p.setPushEnabled(dto.pushEnabled());
            p.setUpdatedAt(now);
            stored.put(dto.type(), p);
        }
        preferenceRepository.saveAll(stored.values());
        return getPreferences(userId);
    }

    @Transactional(readOnly = true)
    public NotificationSettingsDto getSettings(UUID userId) {
        NotificationSettings s = settingsRepository.findById(userId).orElse(null);
        String zone = s != null && s.getTimezone() != null ? s.getTimezone() : accountTimezone(userId);
        return new NotificationSettingsDto(
                s != null && s.isQuietHoursEnabled(),
                s == null ? null : format(s.getQuietHoursStart()),
                s == null ? null : format(s.getQuietHoursEnd()),
                QuietHours.zoneOrUtc(zone).getId());
    }

    /**
     * Saves quiet hours. Enabling them requires both times; start equal to end is rejected.
     * Disabled quiet hours keep the given times so the picker remembers them. A null timezone
     * keeps the stored one (or follows the account's timezone when none is stored).
     */
    @Transactional
    public NotificationSettingsDto updateSettings(UUID userId, NotificationSettingsDto dto) {
        LocalTime start = parse(dto.quietHoursStart());
        LocalTime end = parse(dto.quietHoursEnd());
        if (Boolean.TRUE.equals(dto.quietHoursEnabled())) {
            if (start == null || end == null) {
                throw ApiException.badRequest("VALIDATION_ERROR", "Quiet hours need a start and an end time");
            }
            if (start.equals(end)) {
                throw ApiException.badRequest("VALIDATION_ERROR", "Quiet hours start and end must differ");
            }
        }
        String zone = null;
        if (dto.timezone() != null && !dto.timezone().isBlank()) {
            try {
                zone = ZoneId.of(dto.timezone().trim()).getId();
            } catch (DateTimeException e) {
                throw ApiException.badRequest("VALIDATION_ERROR", "Unknown timezone");
            }
        }

        NotificationSettings s = settingsRepository.findById(userId).orElseGet(() -> new NotificationSettings(userId));
        s.setQuietHoursEnabled(Boolean.TRUE.equals(dto.quietHoursEnabled()));
        s.setQuietHoursStart(start);
        s.setQuietHoursEnd(end);
        if (zone != null) {
            s.setTimezone(zone);
        }
        s.setUpdatedAt(Instant.now());
        settingsRepository.save(s);
        return getSettings(userId);
    }

    private String accountTimezone(UUID userId) {
        List<String> rows = jdbc.query("SELECT timezone FROM users WHERE id = ?", (rs, i) -> rs.getString(1), userId);
        return rows.isEmpty() ? null : rows.get(0);
    }

    private static LocalTime parse(String hhmm) {
        if (hhmm == null || hhmm.isBlank()) return null;
        if (!hhmm.matches(NotificationSettingsDto.HH_MM)) {
            throw ApiException.badRequest("VALIDATION_ERROR", "Times must be HH:mm");
        }
        return LocalTime.parse(hhmm);
    }

    private static String format(LocalTime time) {
        return time == null ? null : String.format("%02d:%02d", time.getHour(), time.getMinute());
    }
}
