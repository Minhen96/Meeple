package com.meeplehearth.notification.service;

import com.meeplehearth.notification.entity.Notification.NotificationType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Time;
import java.time.LocalTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Read-only lookups the delivery pipeline needs, each a single indexed query:
 * <ul>
 *   <li>{@link #recipient}: the recipient's language, preference for the type, quiet hours and
 *       block status in one row;</li>
 *   <li>{@link #context}: the names a message template needs (actor, event title, game).</li>
 * </ul>
 * Other packages' tables are only read here, never written.
 */
@Component
public class NotificationLookups {

    private final JdbcTemplate jdbc;

    public NotificationLookups(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * Everything that decides whether and how a notification is delivered to one recipient.
     *
     * @param blocked either user blocked the other (the notification is dropped)
     */
    public record Recipient(String language, boolean deleted, boolean inAppEnabled, boolean pushEnabled,
                            QuietHours quietHours, boolean blocked) {
    }

    /** @return null when the recipient does not exist */
    public Recipient recipient(UUID recipientId, NotificationType type, UUID actorId) {
        String blockedSql = actorId == null ? "FALSE"
                : "EXISTS (SELECT 1 FROM blocked_users b WHERE (b.blocker_id = u.id AND b.blocked_id = ?)"
                + " OR (b.blocker_id = ? AND b.blocked_id = u.id))";
        String sql = "SELECT u.preferred_language, u.timezone AS user_tz, u.deleted_at IS NOT NULL AS deleted,"
                + " s.quiet_hours_enabled, s.quiet_hours_start, s.quiet_hours_end, s.timezone AS settings_tz,"
                + " p.in_app_enabled, p.push_enabled, " + blockedSql + " AS blocked"
                + " FROM users u"
                + " LEFT JOIN notification_settings s ON s.user_id = u.id"
                + " LEFT JOIN notification_preferences p ON p.user_id = u.id AND p.type = ?"
                + " WHERE u.id = ?";
        Object[] args = actorId == null
                ? new Object[]{type.name(), recipientId}
                : new Object[]{actorId, actorId, type.name(), recipientId};
        List<Recipient> rows = jdbc.query(sql, (rs, i) -> mapRecipient(rs), args);
        return rows.isEmpty() ? null : rows.get(0);
    }

    private static Recipient mapRecipient(ResultSet rs) throws SQLException {
        String zone = rs.getString("settings_tz") != null ? rs.getString("settings_tz") : rs.getString("user_tz");
        QuietHours quietHours = new QuietHours(
                rs.getBoolean("quiet_hours_enabled"),
                toLocalTime(rs.getTime("quiet_hours_start")),
                toLocalTime(rs.getTime("quiet_hours_end")),
                QuietHours.zoneOrUtc(zone));
        Boolean inApp = (Boolean) rs.getObject("in_app_enabled");
        Boolean push = (Boolean) rs.getObject("push_enabled");
        return new Recipient(
                NotificationMessageFactory.normalizeLanguage(rs.getString("preferred_language")),
                rs.getBoolean("deleted"),
                inApp == null || inApp,
                push == null || push,
                quietHours,
                rs.getBoolean("blocked"));
    }

    private static LocalTime toLocalTime(Time time) {
        return time == null ? null : time.toLocalTime();
    }

    /**
     * Names for the message templates. Values the caller passed in {@code extra}
     * ({@code eventTitle}, {@code gameName}, {@code gameId}, {@code count}, {@code path}) win and
     * skip the corresponding lookup.
     */
    public NotificationMessageFactory.Context context(String language, NotificationType type, UUID actorId,
                                                      UUID referenceId, String referenceType,
                                                      Map<String, Object> extra) {
        boolean zh = NotificationMessageFactory.LANG_ZH.equals(language);
        String actorName = actorId == null ? null : actorName(actorId);
        String eventTitle = string(extra, NotificationMessageFactory.EVENT_TITLE);
        String gameName = string(extra, NotificationMessageFactory.GAME_NAME);
        UUID gameId = uuid(extra, NotificationMessageFactory.GAME_ID);
        Integer count = integer(extra, NotificationMessageFactory.COUNT);
        String path = string(extra, NotificationMessageFactory.PATH);
        String ref = referenceType == null ? "" : referenceType.toUpperCase();

        if (eventTitle == null && referenceId != null && type.name().startsWith("EVENT_")
                && (ref.isEmpty() || ref.equals("EVENT"))) {
            eventTitle = single("SELECT title FROM events WHERE id = ?", referenceId);
        }

        if (referenceId != null && (gameName == null || gameId == null || (count == null && type == NotificationType.MATCH_FOUND))) {
            GameRef game = switch (ref) {
                case "MATCH_GROUP" -> gameRef("SELECT g.id, g.name_en, g.name_zh,"
                        + " (SELECT COUNT(*) FROM match_group_members m WHERE m.group_id = mg.id) AS members"
                        + " FROM match_groups mg JOIN games g ON g.id = mg.game_id WHERE mg.id = ?", referenceId);
                case "RULE_NOTE" -> gameRef("SELECT g.id, g.name_en, g.name_zh, NULL AS members"
                        + " FROM game_rule_notes n JOIN games g ON g.id = n.game_id WHERE n.id = ?", referenceId);
                case "RULEBOOK" -> gameRef("SELECT g.id, g.name_en, g.name_zh, NULL AS members"
                        + " FROM game_rulebooks r JOIN games g ON g.id = r.game_id WHERE r.id = ?", referenceId);
                case "GAME" -> gameRef("SELECT g.id, g.name_en, g.name_zh, NULL AS members"
                        + " FROM games g WHERE g.id = ?", referenceId);
                default -> null;
            };
            if (game != null) {
                if (gameName == null) gameName = zh && game.nameZh() != null && !game.nameZh().isBlank()
                        ? game.nameZh() : game.nameEn();
                if (gameId == null) gameId = game.id();
                // Members other than the recipient
                if (count == null && type == NotificationType.MATCH_FOUND && game.members() != null) {
                    count = Math.max(0, game.members() - 1);
                }
            }
        }
        return new NotificationMessageFactory.Context(language, actorName, eventTitle, gameName, gameId, count, path);
    }

    private record GameRef(UUID id, String nameEn, String nameZh, Integer members) {
    }

    private GameRef gameRef(String sql, UUID id) {
        List<GameRef> rows = jdbc.query(sql, (rs, i) -> new GameRef(
                rs.getObject(1, UUID.class), rs.getString(2), rs.getString(3),
                rs.getObject(4) == null ? null : rs.getInt(4)), id);
        return rows.isEmpty() ? null : rows.get(0);
    }

    private String actorName(UUID actorId) {
        List<String> rows = jdbc.query(
                "SELECT COALESCE(NULLIF(display_name, ''), username) FROM users WHERE id = ? AND deleted_at IS NULL",
                (rs, i) -> rs.getString(1), actorId);
        return rows.isEmpty() ? null : rows.get(0);
    }

    private String single(String sql, UUID id) {
        List<String> rows = jdbc.query(sql, (rs, i) -> rs.getString(1), id);
        return rows.isEmpty() ? null : rows.get(0);
    }

    private static String string(Map<String, Object> extra, String key) {
        Object v = extra == null ? null : extra.get(key);
        return v == null ? null : v.toString();
    }

    private static UUID uuid(Map<String, Object> extra, String key) {
        Object v = extra == null ? null : extra.get(key);
        if (v instanceof UUID u) return u;
        if (v instanceof String s) {
            try {
                return UUID.fromString(s);
            } catch (IllegalArgumentException e) {
                return null;
            }
        }
        return null;
    }

    private static Integer integer(Map<String, Object> extra, String key) {
        Object v = extra == null ? null : extra.get(key);
        if (v instanceof Number n) return n.intValue();
        if (v instanceof String s) {
            try {
                return Integer.parseInt(s.trim());
            } catch (NumberFormatException e) {
                return null;
            }
        }
        return null;
    }
}
