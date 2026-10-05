package com.meeplehearth.notification;

import com.meeplehearth.notification.entity.Notification.NotificationType;
import com.meeplehearth.notification.service.NotificationMessageFactory;
import com.meeplehearth.notification.service.NotificationMessageFactory.Context;
import com.meeplehearth.notification.service.NotificationMessageFactory.Rendered;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.junit.jupiter.params.provider.ValueSource;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class NotificationMessageFactoryTest {

    private static final UUID ACTOR = UUID.fromString("00000000-0000-0000-0000-00000000000a");
    private static final UUID REF = UUID.fromString("00000000-0000-0000-0000-0000000000bb");
    private static final UUID GAME = UUID.fromString("00000000-0000-0000-0000-0000000000cc");

    private static Context en(String actor, String event, String game, Integer count) {
        return new Context("en", actor, event, game, null, count, null);
    }

    @ParameterizedTest
    @EnumSource(NotificationType.class)
    void everyTypeRendersInBothLanguagesWithAPath(NotificationType type) {
        Rendered english = NotificationMessageFactory.render(type, ACTOR, REF, null, Context.empty("en"));
        Rendered chinese = NotificationMessageFactory.render(type, ACTOR, REF, null, Context.empty("zh-CN"));
        assertThat(english.title()).isNotBlank().isEqualTo(NotificationMessageFactory.defaultTitle(type));
        assertThat(english.body()).isNotBlank().doesNotContain("{");
        assertThat(chinese.title()).isNotBlank().isNotEqualTo(english.title());
        assertThat(chinese.body()).isNotBlank().doesNotContain("{");
        assertThat(english.path()).startsWith("/");
    }

    @Test
    void rendersTheFeaturesDocTexts() {
        assertThat(NotificationMessageFactory.render(NotificationType.EVENT_INVITE, ACTOR, REF, "EVENT",
                en("Ana", "Catan Night", null, null)))
                .isEqualTo(new Rendered("Game Night Invite", "Ana invited you to Catan Night", "/events/" + REF));
        assertThat(NotificationMessageFactory.render(NotificationType.EVENT_CANCELLED, ACTOR, REF, "EVENT",
                en(null, "Catan Night", null, null)))
                .isEqualTo(new Rendered("Event Cancelled", "Catan Night has been cancelled", "/events"));
        assertThat(NotificationMessageFactory.render(NotificationType.EVENT_COMPLETED, null, REF, "EVENT",
                en(null, "Catan Night", null, null)).path()).isEqualTo("/posts/create");
        assertThat(NotificationMessageFactory.render(NotificationType.POST_LIKE, ACTOR, REF, "POST",
                en("Ana", null, null, 1)))
                .isEqualTo(new Rendered("New Like", "Ana liked your post", "/posts/" + REF));
    }

    @Test
    void fallsBackToGenericNamesAndCapitalizes() {
        Rendered r = NotificationMessageFactory.render(NotificationType.EVENT_CANCELLED, null, null, null,
                Context.empty("en"));
        assertThat(r.body()).isEqualTo("An event has been cancelled");
        assertThat(r.path()).isEqualTo("/events");
        assertThat(NotificationMessageFactory.render(NotificationType.POST_COMMENT, null, REF, "POST",
                Context.empty("en")).body()).isEqualTo("Someone commented on your post");
        assertThat(NotificationMessageFactory.render(NotificationType.POST_COMMENT, null, REF, "POST",
                Context.empty("zh-CN")).body()).isEqualTo("有人 评论了你的帖子");
    }

    @Test
    void batchedLikesAndCountsReadNaturally() {
        assertThat(body(NotificationType.POST_LIKE, en("Ana", null, null, 2), "en"))
                .isEqualTo("Ana and 1 other liked your post");
        assertThat(body(NotificationType.POST_LIKE, en("Ana", null, null, 5), "en"))
                .isEqualTo("Ana and 4 others liked your post");
        assertThat(body(NotificationType.POST_LIKE, new Context("zh-CN", "Ana", null, null, null, 3, null), "zh"))
                .isEqualTo("Ana 和其他 2 人赞了你的帖子");
        assertThat(body(NotificationType.MATCH_FOUND, en(null, null, "Catan", 3), "en"))
                .isEqualTo("3 friends want to play Catan");
        assertThat(body(NotificationType.MATCH_FOUND, en(null, null, "Catan", 1), "en"))
                .isEqualTo("1 friend wants to play Catan");
        assertThat(body(NotificationType.MATCH_FOUND, en(null, null, "Catan", null), "en"))
                .isEqualTo("Friends want to play Catan");
        assertThat(body(NotificationType.BGG_IMPORT_COMPLETED, en(null, null, null, 12), "en"))
                .isEqualTo("12 games were imported from BoardGameGeek");
        assertThat(body(NotificationType.BGG_IMPORT_COMPLETED, en(null, null, null, 1), "en"))
                .isEqualTo("1 game was imported from BoardGameGeek");
        assertThat(body(NotificationType.BGG_IMPORT_COMPLETED, en(null, null, null, null), "en"))
                .isEqualTo("Your BoardGameGeek collection was imported");
    }

    private static String body(NotificationType type, Context ctx, String ignored) {
        return NotificationMessageFactory.render(type, ACTOR, REF, null, ctx).body();
    }

    @Test
    void pathsFollowTheDeepLinkSchema() {
        assertThat(NotificationMessageFactory.defaultPath(NotificationType.FRIEND_REQUEST, ACTOR, REF, "FRIEND_REQUEST"))
                .isEqualTo("/profile/" + ACTOR);
        assertThat(NotificationMessageFactory.defaultPath(NotificationType.FRIEND_ACCEPTED, null, REF, null))
                .isEqualTo("/notifications");
        assertThat(NotificationMessageFactory.defaultPath(NotificationType.MATCH_FOUND, null, REF, "MATCH_GROUP"))
                .isEqualTo("/");
        assertThat(NotificationMessageFactory.defaultPath(NotificationType.MATCH_ACCEPTED, ACTOR, REF, "EVENT"))
                .isEqualTo("/events/" + REF);
        assertThat(NotificationMessageFactory.defaultPath(NotificationType.MATCH_ACCEPTED, ACTOR, REF, "MATCH_GROUP"))
                .isEqualTo("/");
        assertThat(NotificationMessageFactory.defaultPath(NotificationType.COMMENT_MENTION, ACTOR, REF, "COMMENT"))
                .isEqualTo("/");
        assertThat(NotificationMessageFactory.defaultPath(NotificationType.EVENT_RSVP, ACTOR, null, "EVENT"))
                .isEqualTo("/events");
        assertThat(NotificationMessageFactory.defaultPath(NotificationType.RULEBOOK_APPROVED, null, REF, "GAME"))
                .isEqualTo("/library/" + REF);
        assertThat(NotificationMessageFactory.defaultPath(NotificationType.RULE_NOTE_APPROVED, null, REF, "RULE_NOTE"))
                .isEqualTo("/library");
        assertThat(NotificationMessageFactory.render(NotificationType.RULE_NOTE_APPROVED, null, REF, "RULE_NOTE",
                new Context("en", null, null, "Catan", GAME, null, null)).path()).isEqualTo("/library/" + GAME);
        assertThat(NotificationMessageFactory.defaultPath(NotificationType.BGG_IMPORT_COMPLETED, null, null, null))
                .isEqualTo("/library");
    }

    @Test
    void callerPathOverridesOnlyWhenItIsAnInAppPath() {
        Context withPath = new Context("en", null, null, null, null, null, "/posts/123#c9");
        assertThat(NotificationMessageFactory.render(NotificationType.COMMENT_MENTION, ACTOR, REF, "COMMENT", withPath)
                .path()).isEqualTo("/posts/123#c9");
    }

    @ParameterizedTest
    @ValueSource(strings = {"https://evil.test", "//evil.test", "/\\evil", "javascript:alert(1)", "/a b", ""})
    void unsafeCallerPathsAreIgnored(String path) {
        Context withPath = new Context("en", null, null, null, null, null, path);
        assertThat(NotificationMessageFactory.render(NotificationType.POST_TAG, ACTOR, REF, "POST", withPath).path())
                .isEqualTo("/posts/" + REF);
    }

    @Test
    void dataKeepsScalarExtrasStringifiesTheRestAndAddsCountAndPath() {
        Map<String, Object> extra = new LinkedHashMap<>();
        extra.put("eventTitle", "Catan Night");
        extra.put("gameId", GAME);
        extra.put("flag", true);
        extra.put("skip", null);
        extra.put("path", "https://evil.test");
        Map<String, Object> data = NotificationMessageFactory.data(extra, new Rendered("t", "b", "/events/1"), 4);
        assertThat(data).containsEntry("eventTitle", "Catan Night")
                .containsEntry("gameId", GAME.toString())
                .containsEntry("flag", true)
                .containsEntry("count", 4)
                .containsEntry("path", "/events/1")
                .doesNotContainKey("skip");
    }

    @Test
    void normalizesLanguages() {
        assertThat(NotificationMessageFactory.normalizeLanguage("zh")).isEqualTo("zh-CN");
        assertThat(NotificationMessageFactory.normalizeLanguage("ZH-tw")).isEqualTo("zh-CN");
        assertThat(NotificationMessageFactory.normalizeLanguage("fr")).isEqualTo("en");
        assertThat(NotificationMessageFactory.normalizeLanguage(null)).isEqualTo("en");
    }
}
