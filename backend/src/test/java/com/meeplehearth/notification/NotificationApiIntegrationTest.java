package com.meeplehearth.notification;

import com.fasterxml.jackson.databind.JsonNode;
import com.meeplehearth.notification.entity.Notification.NotificationType;
import com.meeplehearth.notification.service.NotificationService;
import com.meeplehearth.support.social.ApiIntegrationTestBase;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.MediaType;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Notification REST API end to end against real Postgres and Redis. */
class NotificationApiIntegrationTest extends ApiIntegrationTestBase {

    @Autowired private NotificationService notificationService;
    @Autowired private StringRedisTemplate redis;

    private final List<String> redisKeys = new ArrayList<>();

    @AfterEach
    void clearRedis() {
        if (!redisKeys.isEmpty()) redis.delete(redisKeys);
        redisKeys.clear();
    }

    private String unreadKey(UUID userId) {
        String key = "notif:unread:" + userId;
        redisKeys.add(key);
        return key;
    }

    private UUID insert(UUID recipient, UUID actor, NotificationType type, Instant createdAt, boolean read) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO notifications (id, recipient_id, type, actor_id, reference_id, reference_type,"
                        + " read, created_at) VALUES (?, ?, ?, ?, ?, 'POST', ?, ?)",
                id, recipient, type.name(), actor, UUID.randomUUID(), read, ts(createdAt));
        return id;
    }

    // -------------------------------------------------------------------------
    // List
    // -------------------------------------------------------------------------

    @Test
    void cursorPaginationIsStableAcrossInserts() throws Exception {
        UUID me = user();
        Instant base = Instant.now().truncatedTo(ChronoUnit.MICROS).minusSeconds(3600);
        List<UUID> expected = new ArrayList<>();
        // 5 rows sharing one timestamp (tie broken by id) plus 3 distinct ones
        for (int i = 0; i < 5; i++) insert(me, null, NotificationType.MATCH_FOUND, base, false);
        for (int i = 1; i <= 3; i++) insert(me, null, NotificationType.MATCH_FOUND, base.plusSeconds(i), false);
        jdbc.query("SELECT id FROM notifications WHERE recipient_id = ? ORDER BY created_at DESC, id DESC",
                rs -> { expected.add(rs.getObject(1, UUID.class)); }, me);

        JsonNode first = json(mvc.perform(get("/api/v1/notifications?limit=3").with(as(me)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items.length()").value(3))
                .andExpect(jsonPath("$.data.hasMore").value(true))
                .andReturn()).get("data");

        // A new notification arrives between pages: it must not shift the next page
        insert(me, null, NotificationType.MATCH_FOUND, Instant.now(), false);

        List<UUID> seen = new ArrayList<>(ids(first));
        String cursor = first.get("nextCursor").asText();
        while (cursor != null) {
            JsonNode page = json(mvc.perform(get("/api/v1/notifications").param("cursor", cursor).param("limit", "3")
                    .with(as(me))).andExpect(status().isOk()).andReturn()).get("data");
            seen.addAll(ids(page));
            cursor = page.get("hasMore").asBoolean() ? page.get("nextCursor").asText() : null;
            if (cursor == null) assertThat(page.get("nextCursor").isNull()).isTrue();
        }
        assertThat(seen).containsExactlyElementsOf(expected);
    }

    @Test
    void plainIsoCursorReturnsOlderRowsAndBadCursorIs400() throws Exception {
        UUID me = user();
        Instant t = Instant.now().truncatedTo(ChronoUnit.SECONDS).minusSeconds(600);
        insert(me, null, NotificationType.MATCH_FOUND, t.minusSeconds(10), false);
        insert(me, null, NotificationType.MATCH_FOUND, t, false);
        insert(me, null, NotificationType.MATCH_FOUND, t.plusSeconds(10), false);

        mvc.perform(get("/api/v1/notifications").param("cursor", t.toString()).with(as(me)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items.length()").value(1))
                .andExpect(jsonPath("$.data.hasMore").value(false));
        mvc.perform(get("/api/v1/notifications").param("cursor", "yesterday").with(as(me)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_CURSOR"));
    }

    @Test
    void legacyPageParametersKeepTheOldShape() throws Exception {
        UUID me = user();
        for (int i = 0; i < 3; i++) insert(me, null, NotificationType.MATCH_FOUND, Instant.now().minusSeconds(i), false);

        mvc.perform(get("/api/v1/notifications?page=0&size=2").with(as(me)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(2))
                .andExpect(jsonPath("$.meta.total").value(3))
                .andExpect(jsonPath("$.meta.hasMore").value(true))
                .andExpect(jsonPath("$.data[0].title").value("Play Together?"))
                .andExpect(jsonPath("$.data[0].data.path").value("/"));
    }

    @Test
    void itemsCarryActorSummaryRenderedTextAndPathAndHideOtherUsersRows() throws Exception {
        UUID me = user();
        UUID friend = user();
        UUID stranger = user();
        jdbc.update("UPDATE users SET display_name = 'Ana', avatar_url = 'https://cdn.test/a.webp' WHERE id = ?", friend);
        UUID requestId = UUID.randomUUID();
        notificationService.send(me, NotificationType.FRIEND_REQUEST, friend, requestId, "FRIEND_REQUEST");
        notificationService.send(stranger, NotificationType.FRIEND_REQUEST, friend, requestId, "FRIEND_REQUEST");

        mvc.perform(get("/api/v1/notifications").with(as(me)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items.length()").value(1))
                .andExpect(jsonPath("$.data.items[0].type").value("FRIEND_REQUEST"))
                .andExpect(jsonPath("$.data.items[0].actor.id").value(friend.toString()))
                .andExpect(jsonPath("$.data.items[0].actor.displayName").value("Ana"))
                .andExpect(jsonPath("$.data.items[0].actor.avatarUrl").value("https://cdn.test/a.webp"))
                .andExpect(jsonPath("$.data.items[0].actor.deleted").value(false))
                .andExpect(jsonPath("$.data.items[0].referenceId").value(requestId.toString()))
                .andExpect(jsonPath("$.data.items[0].title").value("Friend Request"))
                .andExpect(jsonPath("$.data.items[0].body").value("Ana sent you a friend request"))
                .andExpect(jsonPath("$.data.items[0].data.path").value("/profile/" + friend))
                .andExpect(jsonPath("$.data.items[0].read").value(false))
                .andExpect(jsonPath("$.data.nextCursor").isEmpty());

        // A deleted actor is reduced to its id
        softDeleteUser(friend);
        mvc.perform(get("/api/v1/notifications").with(as(me)))
                .andExpect(jsonPath("$.data.items[0].actor.deleted").value(true))
                .andExpect(jsonPath("$.data.items[0].actor.displayName").isEmpty());
    }

    // -------------------------------------------------------------------------
    // Read state, unread counter, delete
    // -------------------------------------------------------------------------

    @Test
    void singleReadDecrementsAndReadAllResetsTheRedisCounter() throws Exception {
        UUID me = user();
        UUID a = insert(me, null, NotificationType.MATCH_FOUND, Instant.now().minusSeconds(30), false);
        insert(me, null, NotificationType.MATCH_FOUND, Instant.now().minusSeconds(20), false);
        insert(me, null, NotificationType.MATCH_FOUND, Instant.now().minusSeconds(10), false);
        String key = unreadKey(me);
        redis.delete(key);

        // Cold key: computed from the database, then cached
        mvc.perform(get("/api/v1/notifications/unread-count").with(as(me)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.count").value(3));
        assertThat(redis.opsForValue().get(key)).isEqualTo("3");

        mvc.perform(put("/api/v1/notifications/{id}/read", a).with(as(me))).andExpect(status().isNoContent());
        assertThat(redis.opsForValue().get(key)).isEqualTo("2");
        // Reading again changes nothing
        mvc.perform(put("/api/v1/notifications/{id}/read", a).with(as(me))).andExpect(status().isNoContent());
        assertThat(redis.opsForValue().get(key)).isEqualTo("2");
        assertThat(count("SELECT COUNT(*) FROM notifications WHERE id = ? AND read", a)).isEqualTo(1);

        mvc.perform(put("/api/v1/notifications/read-all").with(as(me))).andExpect(status().isNoContent());
        assertThat(redis.opsForValue().get(key)).isEqualTo("0");
        assertThat(count("SELECT COUNT(*) FROM notifications WHERE recipient_id = ? AND NOT read", me)).isZero();
        mvc.perform(get("/api/v1/notifications/unread-count").with(as(me)))
                .andExpect(jsonPath("$.data.count").value(0));
    }

    @Test
    void readAndDeleteOfAnotherUsersNotificationIs404() throws Exception {
        UUID me = user();
        UUID other = user();
        UUID theirs = insert(other, null, NotificationType.MATCH_FOUND, Instant.now(), false);

        mvc.perform(put("/api/v1/notifications/{id}/read", theirs).with(as(me)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("NOTIFICATION_NOT_FOUND"));
        mvc.perform(delete("/api/v1/notifications/{id}", theirs).with(as(me)))
                .andExpect(status().isNotFound());
        assertThat(count("SELECT COUNT(*) FROM notifications WHERE id = ? AND NOT read AND deleted_at IS NULL", theirs))
                .isEqualTo(1);
    }

    @Test
    void deleteSoftDeletesHidesTheRowAndDecrementsTheCounter() throws Exception {
        UUID me = user();
        UUID unread = insert(me, null, NotificationType.MATCH_FOUND, Instant.now().minusSeconds(5), false);
        UUID read = insert(me, null, NotificationType.MATCH_FOUND, Instant.now(), true);
        String key = unreadKey(me);
        redis.opsForValue().set(key, "1");

        mvc.perform(delete("/api/v1/notifications/{id}", read).with(as(me))).andExpect(status().isNoContent());
        assertThat(redis.opsForValue().get(key)).isEqualTo("1");
        mvc.perform(delete("/api/v1/notifications/{id}", unread).with(as(me))).andExpect(status().isNoContent());
        assertThat(redis.opsForValue().get(key)).isEqualTo("0");

        assertThat(count("SELECT COUNT(*) FROM notifications WHERE recipient_id = ? AND deleted_at IS NOT NULL", me))
                .isEqualTo(2);
        mvc.perform(get("/api/v1/notifications").with(as(me)))
                .andExpect(jsonPath("$.data.items.length()").value(0));
        mvc.perform(delete("/api/v1/notifications/{id}", unread).with(as(me))).andExpect(status().isNotFound());
        mvc.perform(put("/api/v1/notifications/{id}/read", unread).with(as(me))).andExpect(status().isNotFound());
    }

    @Test
    void endpointsRequireAuthentication() throws Exception {
        mvc.perform(get("/api/v1/notifications")).andExpect(status().isUnauthorized());
        mvc.perform(post("/api/v1/users/me/fcm-tokens").contentType(MediaType.APPLICATION_JSON)
                .content("{\"token\":\"t\",\"platform\":\"web\"}")).andExpect(status().isUnauthorized());
    }

    // -------------------------------------------------------------------------
    // Preferences and settings
    // -------------------------------------------------------------------------

    @Test
    void preferencesDefaultToEnabledAndUpdatesArePartial() throws Exception {
        UUID me = user();
        mvc.perform(get("/api/v1/notifications/preferences").with(as(me)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(NotificationType.values().length))
                .andExpect(jsonPath("$.data[0].type").value("EVENT_INVITE"))
                .andExpect(jsonPath("$.data[0].inAppEnabled").value(true))
                .andExpect(jsonPath("$.data[0].pushEnabled").value(true));

        String body = toJson(List.of(
                Map.of("type", "POST_LIKE", "inAppEnabled", true, "pushEnabled", false),
                Map.of("type", "MATCH_FOUND", "inAppEnabled", false, "pushEnabled", false)));
        mvc.perform(put("/api/v1/notifications/preferences").with(as(me))
                        .contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(NotificationType.values().length));
        // Updating again (upsert) keeps one row per type
        mvc.perform(put("/api/v1/notifications/preferences").with(as(me))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(List.of(Map.of("type", "POST_LIKE", "inAppEnabled", false, "pushEnabled", false)))))
                .andExpect(status().isOk());

        JsonNode prefs = json(mvc.perform(get("/api/v1/notifications/preferences").with(as(me))).andReturn()).get("data");
        Set<String> checked = new HashSet<>();
        for (JsonNode p : prefs) {
            String type = p.get("type").asText();
            if (type.equals("POST_LIKE") || type.equals("MATCH_FOUND")) {
                assertThat(p.get("inAppEnabled").asBoolean()).isFalse();
                assertThat(p.get("pushEnabled").asBoolean()).isFalse();
                checked.add(type);
            } else {
                assertThat(p.get("inAppEnabled").asBoolean()).isTrue();
            }
        }
        assertThat(checked).hasSize(2);
        assertThat(count("SELECT COUNT(*) FROM notification_preferences WHERE user_id = ?", me)).isEqualTo(2);
    }

    @Test
    void invalidPreferencesAreRejected() throws Exception {
        UUID me = user();
        mvc.perform(put("/api/v1/notifications/preferences").with(as(me)).contentType(MediaType.APPLICATION_JSON)
                        .content("[{\"type\":\"NOPE\",\"inAppEnabled\":true,\"pushEnabled\":true}]"))
                .andExpect(status().isBadRequest());
        mvc.perform(put("/api/v1/notifications/preferences").with(as(me)).contentType(MediaType.APPLICATION_JSON)
                        .content("[{\"type\":\"POST_LIKE\",\"inAppEnabled\":true}]"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
        mvc.perform(put("/api/v1/notifications/preferences").with(as(me)).contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(List.of(
                                Map.of("type", "POST_LIKE", "inAppEnabled", true, "pushEnabled", true),
                                Map.of("type", "POST_LIKE", "inAppEnabled", false, "pushEnabled", true)))))
                .andExpect(status().isBadRequest());
        assertThat(count("SELECT COUNT(*) FROM notification_preferences WHERE user_id = ?", me)).isZero();
    }

    @Test
    void settingsDefaultToOffInTheAccountTimezoneAndValidate() throws Exception {
        UUID me = user();
        mvc.perform(get("/api/v1/notifications/settings").with(as(me)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.quietHoursEnabled").value(false))
                .andExpect(jsonPath("$.data.quietHoursStart").isEmpty())
                .andExpect(jsonPath("$.data.timezone").value("UTC"));
        jdbc.update("UPDATE users SET timezone = 'Asia/Shanghai' WHERE id = ?", me);
        mvc.perform(get("/api/v1/notifications/settings").with(as(me)))
                .andExpect(jsonPath("$.data.timezone").value("Asia/Shanghai"));

        mvc.perform(put("/api/v1/notifications/settings").with(as(me)).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"quietHoursEnabled\":true,\"quietHoursStart\":\"22:00\",\"quietHoursEnd\":\"07:30\","
                                + "\"timezone\":\"Europe/Paris\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.quietHoursEnabled").value(true))
                .andExpect(jsonPath("$.data.quietHoursStart").value("22:00"))
                .andExpect(jsonPath("$.data.quietHoursEnd").value("07:30"))
                .andExpect(jsonPath("$.data.timezone").value("Europe/Paris"));

        // Disabling keeps the times and the stored timezone
        mvc.perform(put("/api/v1/notifications/settings").with(as(me)).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"quietHoursEnabled\":false,\"quietHoursStart\":\"22:00\",\"quietHoursEnd\":\"07:30\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.quietHoursEnabled").value(false))
                .andExpect(jsonPath("$.data.quietHoursStart").value("22:00"))
                .andExpect(jsonPath("$.data.timezone").value("Europe/Paris"));

        for (String bad : List.of(
                "{\"quietHoursEnabled\":true,\"quietHoursStart\":\"22:00\"}",
                "{\"quietHoursEnabled\":true,\"quietHoursStart\":\"22:00\",\"quietHoursEnd\":\"22:00\"}",
                "{\"quietHoursEnabled\":true,\"quietHoursStart\":\"25:00\",\"quietHoursEnd\":\"07:00\"}",
                "{\"quietHoursEnabled\":false,\"timezone\":\"Mars/Base\"}",
                "{\"quietHoursStart\":\"22:00\"}")) {
            mvc.perform(put("/api/v1/notifications/settings").with(as(me)).contentType(MediaType.APPLICATION_JSON)
                    .content(bad)).andExpect(status().isBadRequest());
        }
    }

    // -------------------------------------------------------------------------
    // FCM tokens
    // -------------------------------------------------------------------------

    @Test
    void fcmTokensRegisterIdempotentlyMoveBetweenAccountsAndUnregister() throws Exception {
        UUID me = user();
        UUID other = user();
        String token = "tok-" + UUID.randomUUID() + ":APA91b_x-y";

        register(me, token, "web", "Chrome").andExpect(status().isNoContent());
        register(me, token, "web", null).andExpect(status().isNoContent());
        assertThat(count("SELECT COUNT(*) FROM user_fcm_tokens WHERE user_id = ?", me)).isEqualTo(1);
        assertThat(string("SELECT device_info FROM user_fcm_tokens WHERE user_id = ?", me)).isEqualTo("Chrome");

        // Same device signs in as someone else: the token follows the new account
        register(other, token, "web", null).andExpect(status().isNoContent());
        assertThat(count("SELECT COUNT(*) FROM user_fcm_tokens WHERE fcm_token = ?", token)).isEqualTo(1);
        assertThat(count("SELECT COUNT(*) FROM user_fcm_tokens WHERE user_id = ?", other)).isEqualTo(1);

        // Unregister is scoped to the caller and idempotent
        mvc.perform(delete("/api/v1/users/me/fcm-tokens/{token}", token).with(as(me))).andExpect(status().isNoContent());
        assertThat(count("SELECT COUNT(*) FROM user_fcm_tokens WHERE user_id = ?", other)).isEqualTo(1);
        mvc.perform(delete("/api/v1/users/me/fcm-tokens/{token}", token).with(as(other))).andExpect(status().isNoContent());
        mvc.perform(delete("/api/v1/users/me/fcm-tokens/{token}", token).with(as(other))).andExpect(status().isNoContent());
        assertThat(count("SELECT COUNT(*) FROM user_fcm_tokens WHERE fcm_token = ?", token)).isZero();
    }

    @Test
    void fcmTokensAreCappedPerUserAndValidated() throws Exception {
        UUID me = user();
        for (int i = 0; i < 12; i++) {
            register(me, "cap-" + i + "-" + UUID.randomUUID(), "android", "Pixel").andExpect(status().isNoContent());
        }
        assertThat(count("SELECT COUNT(*) FROM user_fcm_tokens WHERE user_id = ?", me)).isEqualTo(10);

        register(me, "t", "windows", null).andExpect(status().isBadRequest());
        register(me, " ", "ios", null).andExpect(status().isBadRequest());
        register(me, "x".repeat(256), "ios", null).andExpect(status().isBadRequest());
    }

    private org.springframework.test.web.servlet.ResultActions register(UUID userId, String token, String platform,
                                                                       String deviceInfo) throws Exception {
        Map<String, Object> body = new java.util.HashMap<>();
        body.put("token", token);
        body.put("platform", platform);
        if (deviceInfo != null) body.put("deviceInfo", deviceInfo);
        return mvc.perform(post("/api/v1/users/me/fcm-tokens").with(as(userId))
                .contentType(MediaType.APPLICATION_JSON).content(toJson(body)));
    }

    private static List<UUID> ids(JsonNode page) {
        List<UUID> ids = new ArrayList<>();
        page.get("items").forEach(item -> ids.add(UUID.fromString(item.get("id").asText())));
        return ids;
    }
}
