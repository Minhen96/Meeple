package com.meeplehearth.notification.service;

import com.meeplehearth.notification.entity.Notification.NotificationType;

import java.util.EnumMap;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

/**
 * The single place that turns {@code (type, actor, reference)} into the stored title, body and
 * {@code data.path} (FEATURES_COMPLETE section 7.2, deep links per section 12.3 with
 * {@code /library/{gameId}} per GAP_ANALYSIS C8). Callers of {@code NotificationService.send}
 * never build these themselves. Pure: every name it needs arrives in a {@link Context}.
 *
 * <p>Text is rendered in the recipient's preferred language ({@code en} or {@code zh-CN}) because
 * it is stored once and also used as the push notification text.
 */
public final class NotificationMessageFactory {

    /** Key of the deep link inside {@code data}. */
    public static final String PATH = "path";
    public static final String COUNT = "count";
    public static final String EVENT_TITLE = "eventTitle";
    public static final String GAME_NAME = "gameName";
    public static final String GAME_ID = "gameId";

    public static final String LANG_EN = "en";
    public static final String LANG_ZH = "zh-CN";

    static final String HOME = "/";
    static final String EVENTS = "/events";
    static final String LIBRARY = "/library";
    static final String CREATE_POST = "/posts/create";
    static final String NOTIFICATIONS = "/notifications";

    private record Template(String title, String body) {
    }

    private static final Map<NotificationType, Template> EN = new EnumMap<>(NotificationType.class);
    private static final Map<NotificationType, Template> ZH = new EnumMap<>(NotificationType.class);

    static {
        en(NotificationType.EVENT_INVITE, "Game Night Invite", "{actor} invited you to {event}");
        en(NotificationType.EVENT_RSVP, "New Player!", "{actor} joined {event}");
        en(NotificationType.EVENT_LEAVE, "Player Left", "{actor} left {event}");
        en(NotificationType.EVENT_KICKED, "Removed from Event", "You were removed from {event}");
        en(NotificationType.EVENT_CANCELLED, "Event Cancelled", "{event} has been cancelled");
        en(NotificationType.EVENT_UPDATED, "Event Updated", "{event} time has changed");
        en(NotificationType.EVENT_REMINDER, "Game Night Tonight!", "{event} starts in 24 hours");
        en(NotificationType.EVENT_COMPLETED, "Share Your Memories", "How did {event} go?");
        en(NotificationType.MATCH_FOUND, "Play Together?", "{count} friends want to play {game}");
        en(NotificationType.MATCH_ACCEPTED, "Match Accepted", "{actor} accepted your match");
        en(NotificationType.POST_LIKE, "New Like", "{actor} liked your post");
        en(NotificationType.POST_COMMENT, "New Comment", "{actor} commented on your post");
        en(NotificationType.COMMENT_MENTION, "Mentioned You", "{actor} mentioned you in a comment");
        en(NotificationType.POST_TAG, "Tagged in Post", "{actor} tagged you in a post");
        en(NotificationType.FRIEND_REQUEST, "Friend Request", "{actor} sent you a friend request");
        en(NotificationType.FRIEND_ACCEPTED, "New Friend", "You and {actor} are now friends");
        en(NotificationType.RULE_NOTE_APPROVED, "Rule Note Approved", "Your rule note for {game} was approved");
        en(NotificationType.RULE_NOTE_REJECTED, "Rule Note Not Approved", "Your rule note for {game} was not approved");
        en(NotificationType.RULEBOOK_APPROVED, "Rulebook Approved", "The rulebook you submitted for {game} is now live");
        en(NotificationType.RULEBOOK_REJECTED, "Rulebook Not Approved", "The rulebook you submitted for {game} was not approved");
        en(NotificationType.RULEBOOK_UNDER_REVIEW, "Rulebook Under Review", "The rulebook you submitted for {game} is being reviewed");
        en(NotificationType.BGG_IMPORT_COMPLETED, "BGG Import Complete", "{count} games were imported from BoardGameGeek");

        zh(NotificationType.EVENT_INVITE, "游戏之夜邀请", "{actor} 邀请你参加 {event}");
        zh(NotificationType.EVENT_RSVP, "新玩家加入！", "{actor} 加入了 {event}");
        zh(NotificationType.EVENT_LEAVE, "玩家已退出", "{actor} 退出了 {event}");
        zh(NotificationType.EVENT_KICKED, "已被移出活动", "你已被移出 {event}");
        zh(NotificationType.EVENT_CANCELLED, "活动已取消", "{event} 已取消");
        zh(NotificationType.EVENT_UPDATED, "活动已更新", "{event} 的时间已更改");
        zh(NotificationType.EVENT_REMINDER, "今晚有游戏之夜！", "{event} 将在 24 小时后开始");
        zh(NotificationType.EVENT_COMPLETED, "分享你的回忆", "{event} 玩得怎么样？");
        zh(NotificationType.MATCH_FOUND, "一起玩吗？", "{count} 位好友想玩 {game}");
        zh(NotificationType.MATCH_ACCEPTED, "匹配已接受", "{actor} 接受了你的匹配");
        zh(NotificationType.POST_LIKE, "新的点赞", "{actor} 赞了你的帖子");
        zh(NotificationType.POST_COMMENT, "新评论", "{actor} 评论了你的帖子");
        zh(NotificationType.COMMENT_MENTION, "有人提到了你", "{actor} 在评论中提到了你");
        zh(NotificationType.POST_TAG, "你被标记了", "{actor} 在帖子中标记了你");
        zh(NotificationType.FRIEND_REQUEST, "好友请求", "{actor} 向你发送了好友请求");
        zh(NotificationType.FRIEND_ACCEPTED, "新朋友", "你和 {actor} 已成为好友");
        zh(NotificationType.RULE_NOTE_APPROVED, "规则笔记已通过", "你为 {game} 提交的规则笔记已通过审核");
        zh(NotificationType.RULE_NOTE_REJECTED, "规则笔记未通过", "你为 {game} 提交的规则笔记未通过审核");
        zh(NotificationType.RULEBOOK_APPROVED, "规则书已通过", "你为 {game} 提交的规则书已上线");
        zh(NotificationType.RULEBOOK_REJECTED, "规则书未通过", "你为 {game} 提交的规则书未通过审核");
        zh(NotificationType.RULEBOOK_UNDER_REVIEW, "规则书审核中", "你为 {game} 提交的规则书正在审核中");
        zh(NotificationType.BGG_IMPORT_COMPLETED, "BGG 导入完成", "已从 BoardGameGeek 导入 {count} 款游戏");
    }

    private static void en(NotificationType type, String title, String body) {
        EN.put(type, new Template(title, body));
    }

    private static void zh(NotificationType type, String title, String body) {
        ZH.put(type, new Template(title, body));
    }

    private NotificationMessageFactory() {
    }

    /**
     * Names and overrides the templates may need; any of them may be null.
     *
     * @param language  {@link #LANG_EN} or {@link #LANG_ZH}; anything else renders English
     * @param actorName display name (or username) of the actor
     * @param count     {@code MATCH_FOUND}: friends in the group; {@code POST_LIKE}: likes batched
     *                  into this notification; {@code BGG_IMPORT_COMPLETED}: games imported
     * @param path      caller-supplied deep link, used instead of the computed one when safe
     */
    public record Context(String language, String actorName, String eventTitle, String gameName,
                          UUID gameId, Integer count, String path) {

        public static Context empty(String language) {
            return new Context(language, null, null, null, null, null, null);
        }

        public Context withCount(Integer newCount) {
            return new Context(language, actorName, eventTitle, gameName, gameId, newCount, path);
        }
    }

    /** Rendered content: what is stored in {@code title}, {@code body} and {@code data}. */
    public record Rendered(String title, String body, String path) {
    }

    public static Rendered render(NotificationType type, UUID actorId, UUID referenceId, String referenceType,
                                  Context ctx) {
        boolean zh = isChinese(ctx.language());
        Template template = (zh ? ZH : EN).get(type);
        String body = renderBody(type, template.body(), ctx, zh);
        return new Rendered(template.title(), body, path(type, actorId, referenceId, referenceType, ctx));
    }

    /** English title used for rows that have none (created before V36). */
    public static String defaultTitle(NotificationType type) {
        return EN.get(type).title();
    }

    /** Deep link computable from the row alone (no name lookups). */
    public static String defaultPath(NotificationType type, UUID actorId, UUID referenceId, String referenceType) {
        return path(type, actorId, referenceId, referenceType, Context.empty(LANG_EN));
    }

    /** Normalizes a stored or requested language to {@link #LANG_EN} / {@link #LANG_ZH}. */
    public static String normalizeLanguage(String language) {
        return isChinese(language) ? LANG_ZH : LANG_EN;
    }

    // -------------------------------------------------------------------------

    private static boolean isChinese(String language) {
        return language != null && language.toLowerCase(Locale.ROOT).startsWith("zh");
    }

    private static String renderBody(NotificationType type, String template, Context ctx, boolean zh) {
        String actor = present(ctx.actorName()) ? ctx.actorName() : (zh ? "有人" : "Someone");
        String event = present(ctx.eventTitle()) ? ctx.eventTitle() : (zh ? "一场活动" : "an event");
        String game = present(ctx.gameName()) ? ctx.gameName() : (zh ? "一款游戏" : "a game");
        Integer count = ctx.count();

        String body = template;
        if (type == NotificationType.POST_LIKE && count != null && count > 1) {
            int others = count - 1;
            body = zh ? "{actor} 和其他 " + others + " 人赞了你的帖子"
                    : others == 1 ? "{actor} and 1 other liked your post"
                    : "{actor} and " + others + " others liked your post";
        } else if (type == NotificationType.MATCH_FOUND && (count == null || count < 1)) {
            body = zh ? "有好友想玩 {game}" : "Friends want to play {game}";
        } else if (type == NotificationType.MATCH_FOUND && count == 1) {
            body = zh ? "1 位好友想玩 {game}" : "1 friend wants to play {game}";
        } else if (type == NotificationType.BGG_IMPORT_COMPLETED && (count == null || count < 0)) {
            body = zh ? "你的 BoardGameGeek 收藏已导入" : "Your BoardGameGeek collection was imported";
        } else if (type == NotificationType.BGG_IMPORT_COMPLETED && count == 1) {
            body = zh ? "已从 BoardGameGeek 导入 1 款游戏" : "1 game was imported from BoardGameGeek";
        }

        body = body.replace("{actor}", actor)
                .replace("{event}", event)
                .replace("{game}", game)
                .replace("{count}", count == null ? "" : String.valueOf(count));
        return capitalize(body);
    }

    private static String path(NotificationType type, UUID actorId, UUID referenceId, String referenceType,
                               Context ctx) {
        if (isSafePath(ctx.path())) {
            return ctx.path();
        }
        String ref = referenceId == null ? null : referenceId.toString();
        return switch (type) {
            case EVENT_KICKED, EVENT_CANCELLED -> EVENTS;
            case EVENT_COMPLETED -> CREATE_POST;
            case EVENT_INVITE, EVENT_RSVP, EVENT_LEAVE, EVENT_UPDATED, EVENT_REMINDER ->
                    ref != null && isRef(referenceType, "EVENT") ? EVENTS + "/" + ref : EVENTS;
            case MATCH_FOUND -> HOME;
            case MATCH_ACCEPTED -> ref != null && "EVENT".equalsIgnoreCase(referenceType) ? EVENTS + "/" + ref : HOME;
            case POST_LIKE, POST_COMMENT, COMMENT_MENTION, POST_TAG ->
                    ref != null && isRef(referenceType, "POST") ? "/posts/" + ref : HOME;
            case FRIEND_REQUEST, FRIEND_ACCEPTED -> actorId != null ? "/profile/" + actorId : NOTIFICATIONS;
            case RULE_NOTE_APPROVED, RULE_NOTE_REJECTED, RULEBOOK_APPROVED, RULEBOOK_REJECTED,
                 RULEBOOK_UNDER_REVIEW -> {
                if (ctx.gameId() != null) yield LIBRARY + "/" + ctx.gameId();
                yield ref != null && "GAME".equalsIgnoreCase(referenceType) ? LIBRARY + "/" + ref : LIBRARY;
            }
            case BGG_IMPORT_COMPLETED -> LIBRARY;
        };
    }

    /** A missing reference type is accepted as the type's natural one. */
    private static boolean isRef(String referenceType, String expected) {
        return referenceType == null || expected.equalsIgnoreCase(referenceType);
    }

    /** In-app absolute path only: no scheme, no protocol-relative {@code //host}, no backslashes. */
    static boolean isSafePath(String path) {
        return path != null && path.startsWith("/") && !path.startsWith("//") && !path.contains("\\")
                && path.length() <= 500 && path.chars().noneMatch(Character::isWhitespace);
    }

    private static boolean present(String s) {
        return s != null && !s.isBlank();
    }

    private static String capitalize(String s) {
        if (s.isEmpty() || !Character.isLowerCase(s.charAt(0))) return s;
        return Character.toUpperCase(s.charAt(0)) + s.substring(1);
    }

    /**
     * Data stored with the notification: caller extras (scalars kept, anything else stored as its
     * string form) plus {@code count} and {@code path}.
     */
    public static Map<String, Object> data(Map<String, Object> extra, Rendered rendered, Integer count) {
        Map<String, Object> data = new LinkedHashMap<>();
        if (extra != null) {
            extra.forEach((k, v) -> {
                if (k == null || v == null) return;
                boolean scalar = v instanceof String || v instanceof Number || v instanceof Boolean;
                data.put(k, scalar ? v : v.toString());
            });
        }
        if (count != null) data.put(COUNT, count);
        data.put(PATH, rendered.path());
        return data;
    }
}
