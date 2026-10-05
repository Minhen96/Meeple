package com.meeplehearth.notification.service;

import com.meeplehearth.common.dto.PageResponse;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.notification.dto.ActorSummary;
import com.meeplehearth.notification.dto.NotificationCursorPage;
import com.meeplehearth.notification.dto.NotificationResponse;
import com.meeplehearth.notification.entity.Notification;
import com.meeplehearth.notification.entity.Notification.NotificationType;
import com.meeplehearth.notification.presence.WebSocketPresenceListener;
import com.meeplehearth.notification.repository.NotificationRepository;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.ResultSetExtractor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.format.DateTimeParseException;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Creates and serves notifications.
 *
 * <p>Delivery pipeline of {@link #send} (FEATURES_COMPLETE section 7.3):
 * <ol>
 *   <li>read the recipient's preference for the type, quiet hours and language; drop the
 *       notification if the recipient is deleted or either user blocked the other;</li>
 *   <li>always save the row (title, body and {@code data.path} rendered by
 *       {@link NotificationMessageFactory}); with in-app disabled it is saved already read, so it
 *       never counts as unread;</li>
 *   <li>after the caller's transaction commits: increment {@code notif:unread:{id}} and, outside
 *       quiet hours, push {@code {notification, unreadCount}} over WebSocket when in-app is
 *       enabled, and send FCM when push is enabled and {@code ws:online:{id}} is absent.</li>
 * </ol>
 * Likes are batched: within an hour of the last {@code POST_LIKE} about a post, further likes
 * update that notification ("X and N others liked your post") instead of creating new ones.
 */
@Service
public class NotificationService {

    private static final Logger log = LoggerFactory.getLogger(NotificationService.class);

    static final int DEFAULT_LIMIT = 30;
    static final int MAX_LIMIT = 50;
    static final Duration LIKE_BATCH_WINDOW = Duration.ofHours(1);
    /** Distinct likers remembered per batched like notification. */
    static final int MAX_TRACKED_LIKERS = 50;
    static final String LIKER_IDS = "likerIds";
    private static final String CURSOR_SEPARATOR = "_";
    private static final UUID MIN_UUID = new UUID(0L, 0L);

    private final NotificationRepository notificationRepository;
    private final UserRepository userRepository;
    private final WebSocketNotificationService webSocketNotificationService;
    private final NotificationLookups lookups;
    private final UnreadCounter unreadCounter;
    private final WebSocketPresenceListener presence;
    private final FcmService fcmService;
    private final JdbcTemplate jdbc;
    private final Clock clock;

    @Autowired
    public NotificationService(NotificationRepository notificationRepository,
                               UserRepository userRepository,
                               WebSocketNotificationService webSocketNotificationService,
                               NotificationLookups lookups,
                               UnreadCounter unreadCounter,
                               WebSocketPresenceListener presence,
                               FcmService fcmService,
                               JdbcTemplate jdbc) {
        this(notificationRepository, userRepository, webSocketNotificationService, lookups, unreadCounter,
                presence, fcmService, jdbc, Clock.systemUTC());
    }

    NotificationService(NotificationRepository notificationRepository,
                        UserRepository userRepository,
                        WebSocketNotificationService webSocketNotificationService,
                        NotificationLookups lookups,
                        UnreadCounter unreadCounter,
                        WebSocketPresenceListener presence,
                        FcmService fcmService,
                        JdbcTemplate jdbc,
                        Clock clock) {
        this.notificationRepository = notificationRepository;
        this.userRepository = userRepository;
        this.webSocketNotificationService = webSocketNotificationService;
        this.lookups = lookups;
        this.unreadCounter = unreadCounter;
        this.presence = presence;
        this.fcmService = fcmService;
        this.jdbc = jdbc;
        this.clock = clock;
    }

    // -------------------------------------------------------------------------
    // Sending (docs/GAP_ANALYSIS.md section 6.2)
    // -------------------------------------------------------------------------

    /** Notify {@code recipientId}; see the class comment for the delivery rules. */
    @Transactional
    public void send(UUID recipientId, NotificationType type,
                     UUID actorId, UUID referenceId, String referenceType) {
        send(recipientId, type, actorId, referenceId, referenceType, Map.of());
    }

    /**
     * Same as the five-argument form, with values for the message: {@code eventTitle},
     * {@code gameName}, {@code gameId}, {@code count}, {@code path} (an in-app path such as
     * {@code /posts/123}). Values left out are looked up from the reference. Every entry is
     * stored in {@code data}.
     */
    @Transactional
    public void send(UUID recipientId, NotificationType type, UUID actorId, UUID referenceId,
                     String referenceType, Map<String, Object> extra) {
        if (recipientId == null || type == null) {
            return;
        }
        NotificationLookups.Recipient recipient = lookups.recipient(recipientId, type, actorId);
        if (recipient == null || recipient.deleted() || recipient.blocked()) {
            return;
        }
        Map<String, Object> safeExtra = extra == null ? Map.of() : extra;
        NotificationMessageFactory.Context ctx = lookups.context(
                recipient.language(), type, actorId, referenceId, referenceType, safeExtra);

        if (type == NotificationType.POST_LIKE && referenceId != null && actorId != null
                && coalesceLike(recipientId, actorId, referenceId, referenceType, ctx, safeExtra)) {
            return;
        }

        Integer count = type == NotificationType.POST_LIKE ? Integer.valueOf(1) : ctx.count();
        NotificationMessageFactory.Context rendering = ctx.withCount(count);
        NotificationMessageFactory.Rendered rendered =
                NotificationMessageFactory.render(type, actorId, referenceId, referenceType, rendering);

        Notification n = new Notification();
        n.setRecipient(userRepository.getReferenceById(recipientId));
        n.setType(type);
        n.setActorId(actorId);
        n.setReferenceId(referenceId);
        n.setReferenceType(referenceType);
        n.setTitle(rendered.title());
        n.setBody(rendered.body());
        Map<String, Object> data = NotificationMessageFactory.data(safeExtra, rendered, count);
        if (type == NotificationType.POST_LIKE && actorId != null) {
            data.put(LIKER_IDS, new ArrayList<>(List.of(actorId.toString())));
        }
        n.setData(data);
        n.setCreatedAt(now());
        // In-app off: kept as history but never counted or shown as unread
        n.setRead(!recipient.inAppEnabled());
        Notification saved = notificationRepository.save(n);

        NotificationResponse dto = NotificationResponse.from(saved, actorSummary(actorId));
        boolean quiet = recipient.quietHours().isActive(clock.instant());
        afterCommit(() -> {
            try {
                deliver(recipientId, dto, recipient, quiet);
            } catch (RuntimeException e) {
                // The notification is stored; the client catches up on its next fetch
                log.warn("Delivery of notification {} failed: {}", dto.id(), e.toString());
            }
        });
    }

    private void deliver(UUID recipientId, NotificationResponse dto, NotificationLookups.Recipient recipient,
                         boolean quiet) {
        long unread = recipient.inAppEnabled() ? unreadCounter.increment(recipientId) : unreadCounter.get(recipientId);
        if (quiet) {
            return;
        }
        if (recipient.inAppEnabled()) {
            webSocketNotificationService.push(recipientId, dto, unread);
        }
        if (recipient.pushEnabled() && fcmService.isEnabled() && !presence.isOnline(recipientId)) {
            fcmService.sendAsync(new FcmService.PushMessage(
                    dto.id(), recipientId, dto.type(), dto.title(), dto.body(), pushData(dto.data()), unread));
        }
    }

    /** Push data carries scalar values only (FCM data payloads are small string maps). */
    private static Map<String, Object> pushData(Map<String, Object> data) {
        Map<String, Object> out = new LinkedHashMap<>();
        data.forEach((k, v) -> {
            if (v instanceof String || v instanceof Number || v instanceof Boolean) out.put(k, v);
        });
        return out;
    }

    /**
     * Folds a like into the post's like notification from the last hour, if any.
     *
     * @return true if the like was folded in (no new notification)
     */
    private boolean coalesceLike(UUID recipientId, UUID actorId, UUID postId, String referenceType,
                                 NotificationMessageFactory.Context ctx, Map<String, Object> extra) {
        // Serialise concurrent likes on the same post for this recipient
        jdbc.query("SELECT pg_advisory_xact_lock(hashtextextended(?, 0))",
                (ResultSetExtractor<Void>) rs -> null, "notif:like:" + recipientId + ":" + postId);

        Notification existing = notificationRepository.findRecent(recipientId, NotificationType.POST_LIKE.name(),
                postId, clock.instant().minus(LIKE_BATCH_WINDOW)).orElse(null);
        if (existing == null) {
            return false;
        }

        Map<String, Object> data = existing.getData() == null ? new LinkedHashMap<>() : new LinkedHashMap<>(existing.getData());
        List<String> likers = new ArrayList<>();
        if (data.get(LIKER_IDS) instanceof List<?> stored) {
            stored.forEach(id -> likers.add(String.valueOf(id)));
        } else if (existing.getActorId() != null) {
            likers.add(existing.getActorId().toString());
        }
        String liker = actorId.toString();
        if (likers.contains(liker)) {
            // Liked again after unliking: already counted
            return true;
        }
        int count = (data.get(NotificationMessageFactory.COUNT) instanceof Number number ? number.intValue() : 1) + 1;
        if (likers.size() < MAX_TRACKED_LIKERS) {
            likers.add(liker);
        }

        NotificationMessageFactory.Rendered rendered = NotificationMessageFactory.render(
                NotificationType.POST_LIKE, actorId, postId, referenceType, ctx.withCount(count));
        Map<String, Object> updated = NotificationMessageFactory.data(extra, rendered, count);
        updated.put(LIKER_IDS, likers);
        existing.setActorId(actorId);
        existing.setTitle(rendered.title());
        existing.setBody(rendered.body());
        existing.setData(updated);
        notificationRepository.save(existing);
        return true;
    }

    // -------------------------------------------------------------------------
    // Reading
    // -------------------------------------------------------------------------

    /**
     * Cursor page, newest first. {@code cursor} is a previous {@code nextCursor}, or an ISO-8601
     * instant meaning "older than this".
     */
    @Transactional(readOnly = true)
    public NotificationCursorPage list(UUID userId, String cursor, Integer limit) {
        int size = clampLimit(limit, DEFAULT_LIMIT);
        List<Notification> rows;
        if (cursor == null || cursor.isBlank()) {
            rows = notificationRepository.findFirstPage(userId, size + 1);
        } else {
            Cursor c = Cursor.parse(cursor);
            rows = notificationRepository.findPageBefore(userId, c.createdAt(), c.id(), size + 1);
        }
        boolean hasMore = rows.size() > size;
        List<Notification> page = hasMore ? rows.subList(0, size) : rows;
        String nextCursor = null;
        if (hasMore) {
            Notification last = page.get(page.size() - 1);
            nextCursor = last.getCreatedAt().toString() + CURSOR_SEPARATOR + last.getId();
        }
        return new NotificationCursorPage(toResponses(page), nextCursor, hasMore);
    }

    /** Legacy offset page ({@code ?page=&size=}, page 0-based) in the {@code {data, meta}} shape. */
    @Transactional(readOnly = true)
    public PageResponse<NotificationResponse> getNotifications(UUID userId, int page, int size) {
        Page<Notification> result = notificationRepository.findPage(
                userId, PageRequest.of(Math.max(0, page), clampLimit(size, 20)));
        List<NotificationResponse> items = toResponses(result.getContent());
        Map<UUID, NotificationResponse> byId = items.stream()
                .collect(Collectors.toMap(NotificationResponse::id, Function.identity()));
        return PageResponse.of(result, n -> byId.get(n.getId()));
    }

    public long getUnreadCount(UUID userId) {
        return unreadCounter.get(userId);
    }

    /** Maps rows to DTOs, loading every actor in one query. */
    private List<NotificationResponse> toResponses(List<Notification> rows) {
        Set<UUID> actorIds = rows.stream().map(Notification::getActorId).filter(Objects::nonNull)
                .collect(Collectors.toCollection(LinkedHashSet::new));
        Map<UUID, ActorSummary> actors = new HashMap<>();
        if (!actorIds.isEmpty()) {
            for (User u : userRepository.findAllById(actorIds)) {
                actors.put(u.getId(), ActorSummary.from(u));
            }
        }
        return rows.stream()
                .map(n -> NotificationResponse.from(n, n.getActorId() == null ? null : actors.get(n.getActorId())))
                .toList();
    }

    private ActorSummary actorSummary(UUID actorId) {
        if (actorId == null) return null;
        return userRepository.findById(actorId).map(ActorSummary::from).orElse(null);
    }

    // -------------------------------------------------------------------------
    // Read state and delete
    // -------------------------------------------------------------------------

    @Transactional
    public void markRead(UUID userId, UUID notificationId) {
        if (notificationRepository.findOwned(notificationId, userId).isEmpty()) {
            throw ApiException.notFound("NOTIFICATION_NOT_FOUND", "Notification not found");
        }
        if (notificationRepository.markRead(notificationId, userId) > 0) {
            afterCommit(() -> unreadCounter.decrement(userId));
        }
    }

    @Transactional
    public void markAllRead(UUID userId) {
        notificationRepository.markAllReadForUser(userId);
        // Evict now so reads in this transaction recompute; set 0 once the update is visible
        unreadCounter.evict(userId);
        afterCommit(() -> unreadCounter.reset(userId));
    }

    /** Soft delete ({@code deleted_at}); the retention job removes the row later. */
    @Transactional
    public void delete(UUID userId, UUID notificationId) {
        Notification n = notificationRepository.findOwned(notificationId, userId)
                .orElseThrow(() -> ApiException.notFound("NOTIFICATION_NOT_FOUND", "Notification not found"));
        boolean wasUnread = !n.isRead();
        n.setDeletedAt(clock.instant());
        notificationRepository.save(n);
        if (wasUnread) {
            afterCommit(() -> unreadCounter.decrement(userId));
        }
    }

    // -------------------------------------------------------------------------

    private Instant now() {
        // Postgres keeps microseconds: store exactly what cursors will read back
        return clock.instant().truncatedTo(ChronoUnit.MICROS);
    }

    static int clampLimit(Integer limit, int fallback) {
        if (limit == null || limit < 1) return fallback;
        return Math.min(limit, MAX_LIMIT);
    }

    /** Runs {@code action} after the current transaction commits, or now without one. */
    static void afterCommit(Runnable action) {
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    action.run();
                }
            });
        } else {
            action.run();
        }
    }

    /** {@code nextCursor} = {@code {createdAt ISO}_{id}}; a bare ISO instant is also accepted. */
    record Cursor(Instant createdAt, UUID id) {
        static Cursor parse(String raw) {
            String value = raw.trim();
            try {
                int sep = value.lastIndexOf(CURSOR_SEPARATOR);
                if (sep > 0) {
                    return new Cursor(Instant.parse(value.substring(0, sep)), UUID.fromString(value.substring(sep + 1)));
                }
                return new Cursor(Instant.parse(value), MIN_UUID);
            } catch (DateTimeParseException | IllegalArgumentException e) {
                throw ApiException.badRequest("INVALID_CURSOR", "Invalid cursor");
            }
        }
    }
}
