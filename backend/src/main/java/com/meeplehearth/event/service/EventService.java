package com.meeplehearth.event.service;

import com.meeplehearth.common.event.ActivityRecordedEvent;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.event.dto.CreateEventRequest;
import com.meeplehearth.event.dto.EventPageResponse;
import com.meeplehearth.event.dto.EventResponse;
import com.meeplehearth.event.dto.NotInPastBeyondGrace;
import com.meeplehearth.event.dto.UpdateEventRequest;
import com.meeplehearth.event.entity.Event;
import com.meeplehearth.event.entity.EventParticipant;
import com.meeplehearth.event.entity.EventParticipant.RsvpStatus;
import com.meeplehearth.event.repository.EventParticipantRepository;
import com.meeplehearth.event.repository.EventRepository;
import com.meeplehearth.event.service.EventLiveUpdatePublisher.EventChanged;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.notification.entity.Notification.NotificationType;
import com.meeplehearth.notification.service.NotificationService;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.Base64;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Events: create (with invites), update, cancel, invite, RSVP / leave / kick, and the list views
 * (FEATURES section 4, ENGINEERING_STANDARDS section 10).
 *
 * <p>Join rules (decision C9): PUBLIC events are open-join; FRIENDS and INVITE_ONLY events need
 * an invite. Every capacity-affecting change row-locks the event first, so concurrent joins for
 * the last spot are serialised and exactly one succeeds.
 */
@Service
public class EventService {

    public static final int MAX_LIST_LIMIT = 100;
    public static final int DEFAULT_LIST_LIMIT = 50;
    public static final int DEFAULT_COMMUNITY_LIMIT = 20;
    /** Longest calendar range (two months plus the partial weeks around them). */
    public static final Duration MAX_CALENDAR_RANGE = Duration.ofDays(62);
    static final int MAX_CALENDAR_EVENTS = 500;
    /** Events starting sooner than this get no reminder (FEATURES section 4.5 edge case). */
    static final Duration REMINDER_LEAD = Duration.ofHours(24);
    static final String REFERENCE_TYPE = "EVENT";
    private static final UUID MIN_UUID = new UUID(0L, 0L);

    /** Who an invite list may contain and whether invitees get an EVENT_INVITE notification. */
    private enum InvitePolicy {
        /** API: friends of the host only (403 NOT_FRIENDS otherwise); invitees notified. */
        FRIENDS_ONLY,
        /**
         * Match acceptance: members of the match group, who may be friends-of-friends; anyone
         * blocked with the host or deleted is silently skipped and nobody gets EVENT_INVITE (the
         * match flow sends MATCH_ACCEPTED instead).
         */
        MATCH_MEMBERS
    }

    public enum ListScope { UPCOMING, PAST, MINE }

    private final EventRepository eventRepository;
    private final EventParticipantRepository participantRepository;
    private final UserRepository userRepository;
    private final GameRepository gameRepository;
    private final NotificationService notificationService;
    private final EventResponseAssembler assembler;
    private final ApplicationEventPublisher eventPublisher;

    public EventService(EventRepository eventRepository,
                        EventParticipantRepository participantRepository,
                        UserRepository userRepository,
                        GameRepository gameRepository,
                        NotificationService notificationService,
                        EventResponseAssembler assembler,
                        ApplicationEventPublisher eventPublisher) {
        this.eventRepository = eventRepository;
        this.participantRepository = participantRepository;
        this.userRepository = userRepository;
        this.gameRepository = gameRepository;
        this.notificationService = notificationService;
        this.assembler = assembler;
        this.eventPublisher = eventPublisher;
    }

    // -------------------------------------------------------------------------
    // Lists
    // -------------------------------------------------------------------------

    /** Upcoming events in the viewer's circle (hosting, invited, friends' events), soonest first. */
    @Transactional(readOnly = true)
    public List<EventResponse> getUpcomingEvents(UUID viewerId, int limit) {
        List<Event> events = eventRepository.findUpcomingInCircle(
                Instant.now(), viewerId, PageRequest.of(0, clampLimit(limit)));
        return assembler.toResponses(events, viewerId);
    }

    /** Events the viewer hosted or attended that have started or completed, most recent first. */
    @Transactional(readOnly = true)
    public List<EventResponse> getPastEvents(UUID viewerId, int limit) {
        List<Event> events = eventRepository.findPastForViewer(
                Instant.now(), viewerId, PageRequest.of(0, clampLimit(limit)));
        return assembler.toResponses(events, viewerId);
    }

    @Transactional(readOnly = true)
    public List<EventResponse> getMyEvents(UUID viewerId) {
        return assembler.toResponses(eventRepository.findAcceptedVisibleByUserId(viewerId), viewerId);
    }

    @Transactional(readOnly = true)
    public List<EventResponse> listEvents(UUID viewerId, ListScope scope, int limit) {
        return switch (scope) {
            case UPCOMING -> getUpcomingEvents(viewerId, limit);
            case PAST -> getPastEvents(viewerId, limit);
            case MINE -> getMyEvents(viewerId).stream().limit(clampLimit(limit)).toList();
        };
    }

    /** Events in the viewer's circle starting in {@code [from, to)}; the range is at most 62 days. */
    @Transactional(readOnly = true)
    public List<EventResponse> getCalendar(UUID viewerId, Instant from, Instant to) {
        if (!from.isBefore(to)) {
            throw ApiException.badRequest("INVALID_RANGE", "'from' must be before 'to'");
        }
        if (Duration.between(from, to).compareTo(MAX_CALENDAR_RANGE) > 0) {
            throw ApiException.badRequest("INVALID_RANGE", "The calendar range can be at most 62 days");
        }
        List<Event> events = eventRepository.findCalendarForViewer(
                from, to, viewerId, PageRequest.of(0, MAX_CALENDAR_EVENTS));
        return assembler.toResponses(events, viewerId);
    }

    /**
     * Community tab: upcoming PUBLIC events from anyone (blocked hosts excluded), soonest first,
     * optionally for one game. Keyset pagination: {@code cursor} is the previous page's
     * {@code nextCursor}.
     */
    @Transactional(readOnly = true)
    public EventPageResponse getCommunityEvents(UUID viewerId, UUID gameId, String cursor, int limit) {
        int size = clampLimit(limit);
        Instant now = Instant.now();
        Instant afterTime = now;
        UUID afterId = MIN_UUID;
        if (cursor != null && !cursor.isBlank()) {
            CommunityCursor decoded = CommunityCursor.decode(cursor);
            afterTime = decoded.scheduledAt();
            afterId = decoded.id();
        }
        PageRequest page = PageRequest.of(0, size + 1);
        List<Event> rows = gameId == null
                ? eventRepository.findCommunityPage(now, afterTime, afterId, viewerId, page)
                : eventRepository.findCommunityPageForGame(now, afterTime, afterId, viewerId, gameId, page);

        boolean hasMore = rows.size() > size;
        List<Event> events = hasMore ? rows.subList(0, size) : rows;
        String nextCursor = hasMore
                ? new CommunityCursor(events.get(size - 1).getScheduledAt(), events.get(size - 1).getId()).encode()
                : null;
        return new EventPageResponse(assembler.toResponses(events, viewerId), nextCursor, hasMore);
    }

    // -------------------------------------------------------------------------
    // Single event
    // -------------------------------------------------------------------------

    /**
     * A visible event; a cancelled one is still returned (status CANCELLED) to its host and to
     * people who were invited or going, so they can see why it disappeared.
     */
    @Transactional(readOnly = true)
    public EventResponse getEvent(UUID eventId, UUID viewerId) {
        Event event = eventRepository.findVisibleById(eventId, viewerId)
                .or(() -> eventRepository.findCancelledForParticipant(eventId, viewerId))
                .orElseThrow(EventService::eventNotFound);
        return assembler.toResponse(event, viewerId);
    }

    // -------------------------------------------------------------------------
    // Create
    // -------------------------------------------------------------------------

    @Transactional
    public EventResponse createEvent(UUID hostId, CreateEventRequest req) {
        return create(hostId, req, InvitePolicy.FRIENDS_ONLY);
    }

    /**
     * Creates the event for an accepted match group: {@code invitedUserIds} are the other group
     * members. Unlike {@link #createEvent} they need not be direct friends of the host (the group
     * may be a chain of friends), members blocked with the host are skipped, and invitees are not
     * sent EVENT_INVITE (the caller sends MATCH_ACCEPTED to the invited members it gets back).
     */
    @Transactional
    public EventResponse createEventFromMatch(UUID hostId, CreateEventRequest req) {
        return create(hostId, req, InvitePolicy.MATCH_MEMBERS);
    }

    private EventResponse create(UUID hostId, CreateEventRequest req, InvitePolicy policy) {
        User host = userRepository.findById(hostId)
                .orElseThrow(() -> ApiException.notFound("USER_NOT_FOUND", "User not found"));
        Instant now = Instant.now();
        if (!NotInPastBeyondGrace.Validator.isAllowed(req.scheduledAt(), now)) {
            throw ApiException.badRequest("INVALID_TIME", "The event cannot start in the past");
        }
        Game game = req.gameId() == null ? null : findGame(req.gameId());
        List<User> invitees = resolveInvitees(hostId, req.invitedUserIds(), policy);

        Event event = new Event();
        event.setHost(host);
        event.setGame(game);
        event.setTitle(req.title().trim());
        event.setDescription(blankToNull(req.description()));
        event.setLocation(blankToNull(req.location()));
        event.setLocationDisplay(blankToNull(req.locationDisplay()));
        event.setScheduledAt(req.scheduledAt());
        event.setMaxParticipants(req.maxParticipants() != null
                ? req.maxParticipants() : CreateEventRequest.DEFAULT_MAX_PARTICIPANTS);
        event.setVisibility(Event.Visibility.valueOf(req.visibility()));
        // Last-minute events get no 24h reminder (FEATURES section 4.5)
        event.setReminderSent(req.scheduledAt().isBefore(now.plus(REMINDER_LEAD)));
        Event saved = eventRepository.save(event);

        List<EventParticipant> rows = new ArrayList<>();
        rows.add(new EventParticipant(saved, host, RsvpStatus.ACCEPTED)); // host always attends
        invitees.forEach(u -> rows.add(new EventParticipant(saved, u, RsvpStatus.INVITED)));
        participantRepository.saveAll(rows);

        if (policy == InvitePolicy.FRIENDS_ONLY) {
            invitees.forEach(u -> notify(u.getId(), NotificationType.EVENT_INVITE, hostId, saved.getId()));
        }
        if (saved.getVisibility() != Event.Visibility.INVITE_ONLY) {
            recordActivity(hostId, ActivityRecordedEvent.EVENT_CREATED, saved, now);
        }
        return assembler.toResponse(saved, hostId);
    }

    // -------------------------------------------------------------------------
    // Update
    // -------------------------------------------------------------------------

    /**
     * Host-only partial update (FEATURES section 4.4): max participants cannot drop below the
     * accepted count; the game cannot change once COMPLETED; a new start time notifies accepted
     * participants (EVENT_UPDATED) and re-arms the 24h reminder.
     */
    @Transactional
    public EventResponse updateEvent(UUID userId, UUID eventId, UpdateEventRequest req) {
        Event event = lockHostedEvent(userId, eventId);
        Instant now = Instant.now();

        if (req.gameId() != null && !isCurrentGame(event, req.gameId())) {
            if (event.getStatus() == Event.EventStatus.COMPLETED) {
                throw ApiException.conflict("EVENT_COMPLETED", "The game cannot change after the event is completed");
            }
            event.setGame(findGame(req.gameId()));
        }
        if (req.title() != null) event.setTitle(req.title().trim());
        if (req.description() != null) event.setDescription(blankToNull(req.description()));
        if (req.location() != null) event.setLocation(blankToNull(req.location()));
        if (req.locationDisplay() != null) event.setLocationDisplay(blankToNull(req.locationDisplay()));
        if (req.visibility() != null) event.setVisibility(Event.Visibility.valueOf(req.visibility()));

        boolean timeChanged = req.scheduledAt() != null && !req.scheduledAt().equals(event.getScheduledAt());
        if (timeChanged) {
            event.setScheduledAt(req.scheduledAt());
            event.setReminderSent(req.scheduledAt().isBefore(now.plus(REMINDER_LEAD)));
        }

        boolean rosterChanged = false;
        if (req.maxParticipants() != null && req.maxParticipants() != event.getMaxParticipants()) {
            int accepted = participantRepository.countAcceptedByEventId(eventId);
            if (req.maxParticipants() < accepted) {
                throw ApiException.conflict("MAX_BELOW_ACCEPTED",
                        "Max players cannot be lower than the " + accepted + " people already going");
            }
            event.setMaxParticipants(req.maxParticipants());
            rosterChanged = refreshCapacityStatus(event, accepted);
        }
        Event saved = eventRepository.save(event);

        if (timeChanged) {
            notifyAccepted(saved, NotificationType.EVENT_UPDATED, userId);
        }
        if (rosterChanged) {
            publishChanged(eventId);
        }
        return assembler.toResponse(saved, userId);
    }

    // -------------------------------------------------------------------------
    // Cancel
    // -------------------------------------------------------------------------

    /**
     * Host-only: status CANCELLED plus soft delete (kept in history), and EVENT_CANCELLED to every
     * accepted participant except the host. A completed event cannot be cancelled.
     */
    @Transactional
    public void cancelEvent(UUID userId, UUID eventId) {
        Event event = lockHostedEvent(userId, eventId);
        if (event.getStatus() == Event.EventStatus.COMPLETED) {
            throw ApiException.conflict("EVENT_COMPLETED", "A completed event cannot be cancelled");
        }
        event.setStatus(Event.EventStatus.CANCELLED);
        event.setDeletedAt(Instant.now());
        eventRepository.save(event);
        notifyAccepted(event, NotificationType.EVENT_CANCELLED, userId);
        publishChanged(eventId);
    }

    // -------------------------------------------------------------------------
    // Invites
    // -------------------------------------------------------------------------

    /**
     * Host-only: invites friends of the host. Users already invited or going are skipped; users
     * who declined, left or were kicked are invited again (FEATURES section 4.2: a re-invite lets
     * them re-join). Each newly invited user gets EVENT_INVITE.
     */
    @Transactional
    public EventResponse inviteUsers(UUID userId, UUID eventId, List<UUID> userIds) {
        Event event = lockHostedEvent(userId, eventId);
        assertLive(event);
        List<User> invitees = resolveInvitees(userId, userIds, InvitePolicy.FRIENDS_ONLY);
        if (invitees.isEmpty()) {
            return assembler.toResponse(loadForResponse(eventId), userId);
        }

        Map<UUID, EventParticipant> existing = participantRepository
                .findByUserIdsForEvent(eventId, invitees.stream().map(User::getId).toList()).stream()
                .collect(Collectors.toMap(ep -> ep.getId().getUserId(), Function.identity()));

        List<EventParticipant> toSave = new ArrayList<>();
        List<UUID> notified = new ArrayList<>();
        for (User invitee : invitees) {
            EventParticipant row = existing.get(invitee.getId());
            if (row == null) {
                toSave.add(new EventParticipant(event, invitee, RsvpStatus.INVITED));
            } else if (row.getStatus() == RsvpStatus.INVITED || row.getStatus() == RsvpStatus.ACCEPTED) {
                continue;
            } else {
                row.setStatus(RsvpStatus.INVITED);
                toSave.add(row);
            }
            notified.add(invitee.getId());
        }
        participantRepository.saveAll(toSave);
        notified.forEach(id -> notify(id, NotificationType.EVENT_INVITE, userId, eventId));
        return assembler.toResponse(loadForResponse(eventId), userId);
    }

    // -------------------------------------------------------------------------
    // RSVP / leave / kick
    // -------------------------------------------------------------------------

    /**
     * Accept or decline. PUBLIC events can be joined without an invite; FRIENDS and INVITE_ONLY
     * need a participant row (an invite, or an earlier decline of one). Kicked users cannot come
     * back on their own, and neither can users who left a non-public event (they need a new
     * invite). Accepting checks capacity under the event row lock.
     */
    @Transactional
    public EventResponse rsvp(UUID userId, UUID eventId, String statusStr) {
        Event event = lockVisibleEvent(userId, eventId);
        User user = userRepository.findById(userId)
                .orElseThrow(() -> ApiException.notFound("USER_NOT_FOUND", "User not found"));
        assertLive(event);

        RsvpStatus target = RsvpStatus.valueOf(statusStr.toUpperCase());
        if (target != RsvpStatus.ACCEPTED && target != RsvpStatus.DECLINED) {
            throw ApiException.badRequest("INVALID_STATUS", "RSVP must be ACCEPTED or DECLINED");
        }
        UUID hostId = event.hostIdOrNull();
        if (event.isHostedBy(userId)) {
            if (target == RsvpStatus.DECLINED) {
                throw ApiException.badRequest("HOST_CANNOT_LEAVE", "Cancel the event or transfer host.");
            }
            return assembler.toResponse(loadForResponse(eventId), userId);
        }

        Optional<EventParticipant> existing = participantRepository.findByEventIdAndUserId(eventId, userId);
        RsvpStatus current = existing.map(EventParticipant::getStatus).orElse(null);
        if (current == target) {
            return assembler.toResponse(loadForResponse(eventId), userId); // idempotent
        }
        assertTransitionAllowed(event, current, target);

        if (target == RsvpStatus.ACCEPTED
                && participantRepository.countAcceptedByEventId(eventId) >= event.getMaxParticipants()) {
            throw ApiException.conflict("EVENT_FULL", "This event is already full");
        }

        if (existing.isPresent()) {
            existing.get().setStatus(target);
            participantRepository.save(existing.get());
        } else {
            participantRepository.save(new EventParticipant(event, user, target));
        }
        boolean statusChanged = refreshCapacityStatus(event, participantRepository.countAcceptedByEventId(eventId));
        if (statusChanged) {
            eventRepository.save(event);
        }

        if (target == RsvpStatus.ACCEPTED) {
            notify(hostId, NotificationType.EVENT_RSVP, userId, eventId);
            if (event.getVisibility() != Event.Visibility.INVITE_ONLY) {
                recordActivity(userId, ActivityRecordedEvent.EVENT_JOINED, event, Instant.now());
            }
        }
        if (target == RsvpStatus.ACCEPTED || current == RsvpStatus.ACCEPTED) {
            publishChanged(eventId);
        }
        return assembler.toResponse(loadForResponse(eventId), userId);
    }

    /**
     * Leave an event you are going to: status becomes LEFT (the row is kept), the host gets
     * EVENT_LEAVE and a FULL event re-opens. Leaving again is a no-op.
     */
    @Transactional
    public void leaveEvent(UUID userId, UUID eventId) {
        Event event = lockVisibleEvent(userId, eventId);
        EventParticipant row = participantRepository.findByEventIdAndUserId(eventId, userId)
                .orElseThrow(() -> ApiException.notFound("RSVP_NOT_FOUND", "You have not RSVP'd to this event"));
        UUID hostId = event.hostIdOrNull();
        if (event.isHostedBy(userId)) {
            throw ApiException.badRequest("HOST_CANNOT_LEAVE", "Cancel the event or transfer host.");
        }
        if (row.getStatus() == RsvpStatus.LEFT) {
            return;
        }
        if (row.getStatus() != RsvpStatus.ACCEPTED) {
            throw ApiException.conflict("NOT_PARTICIPANT", "You are not going to this event");
        }
        assertLive(event);

        row.setStatus(RsvpStatus.LEFT);
        participantRepository.save(row);
        if (refreshCapacityStatus(event, participantRepository.countAcceptedByEventId(eventId))) {
            eventRepository.save(event);
        }
        notify(hostId, NotificationType.EVENT_LEAVE, userId, eventId);
        publishChanged(eventId);
    }

    /**
     * Host-only: removes a participant (status KICKED, so they cannot re-join a PUBLIC event on
     * their own). Someone who was going or invited gets EVENT_KICKED; a FULL event re-opens.
     */
    @Transactional
    public EventResponse kickParticipant(UUID hostId, UUID eventId, UUID targetUserId) {
        Event event = lockHostedEvent(hostId, eventId);
        if (hostId.equals(targetUserId)) {
            throw ApiException.badRequest("CANNOT_KICK_HOST", "The host cannot remove themselves");
        }
        assertLive(event);
        EventParticipant row = participantRepository.findByEventIdAndUserId(eventId, targetUserId)
                .orElseThrow(() -> ApiException.notFound("NOT_PARTICIPANT", "This user is not part of the event"));
        RsvpStatus previous = row.getStatus();
        if (previous != RsvpStatus.KICKED) {
            row.setStatus(RsvpStatus.KICKED);
            participantRepository.save(row);
            if (refreshCapacityStatus(event, participantRepository.countAcceptedByEventId(eventId))) {
                eventRepository.save(event);
            }
            if (previous == RsvpStatus.ACCEPTED || previous == RsvpStatus.INVITED) {
                notify(targetUserId, NotificationType.EVENT_KICKED, hostId, eventId);
            }
            if (previous == RsvpStatus.ACCEPTED) {
                publishChanged(eventId);
            }
        }
        return assembler.toResponse(loadForResponse(eventId), hostId);
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private void assertTransitionAllowed(Event event, RsvpStatus current, RsvpStatus target) {
        if (current == RsvpStatus.KICKED) {
            throw ApiException.forbidden("KICKED", "The host removed you from this event");
        }
        boolean isPublic = event.getVisibility() == Event.Visibility.PUBLIC;
        if (target == RsvpStatus.ACCEPTED) {
            // PUBLIC: open join (also after leaving). Otherwise an invite or an earlier decline of one.
            boolean allowed = isPublic || current == RsvpStatus.INVITED || current == RsvpStatus.DECLINED;
            if (!allowed) {
                throw ApiException.forbidden("NOT_INVITED", "You need an invite to join this event");
            }
            return;
        }
        // DECLINED: answering an invite, never a way to leave (that is DELETE /rsvp)
        if (current == RsvpStatus.ACCEPTED) {
            throw ApiException.conflict("INVALID_STATUS_TRANSITION", "Leave the event instead of declining it");
        }
        if (current != RsvpStatus.INVITED) {
            throw ApiException.forbidden("NOT_INVITED", "You have not been invited to this event");
        }
    }

    /**
     * Resolves and validates an invite list: duplicates are ignored; the host cannot invite
     * themselves; see {@link InvitePolicy} for who may be invited.
     */
    private List<User> resolveInvitees(UUID hostId, List<UUID> requested, InvitePolicy policy) {
        if (requested == null || requested.isEmpty()) {
            return List.of();
        }
        Set<UUID> ids = new LinkedHashSet<>();
        requested.stream().filter(Objects::nonNull).forEach(ids::add);
        if (ids.contains(hostId)) {
            if (policy == InvitePolicy.FRIENDS_ONLY) {
                throw ApiException.badRequest("CANNOT_INVITE_SELF", "You are already part of your own event");
            }
            ids.remove(hostId);
        }
        if (ids.isEmpty()) {
            return List.of();
        }
        Set<UUID> allowed = new HashSet<>(policy == InvitePolicy.FRIENDS_ONLY
                ? eventRepository.findFriendIdsAmong(hostId, ids)
                : eventRepository.findActiveNotBlockedWith(hostId, ids));
        if (policy == InvitePolicy.FRIENDS_ONLY && allowed.size() != ids.size()) {
            throw ApiException.forbidden("NOT_FRIENDS", "You can only invite your friends");
        }
        Map<UUID, User> users = new LinkedHashMap<>();
        userRepository.findAllById(allowed).forEach(u -> users.put(u.getId(), u));
        return ids.stream().map(users::get).filter(Objects::nonNull).toList();
    }

    /**
     * Locks the event row, then hides events the caller cannot see (404, existence not leaked)
     * and rejects callers who can see it but are not the host (403 NOT_HOST).
     */
    private Event lockHostedEvent(UUID userId, UUID eventId) {
        Event event = lockVisibleEvent(userId, eventId);
        if (!event.isHostedBy(userId)) {
            throw ApiException.forbidden("NOT_HOST", "Only the host can do that");
        }
        return event;
    }

    /** Row-locks a non-deleted event the caller can see (block-aware), else 404. */
    private Event lockVisibleEvent(UUID userId, UUID eventId) {
        Event event = eventRepository.findActiveByIdForUpdate(eventId).orElseThrow(EventService::eventNotFound);
        if (!eventRepository.isVisibleTo(eventId, userId)) {
            throw eventNotFound();
        }
        return event;
    }

    private Event loadForResponse(UUID eventId) {
        return eventRepository.findWithHostAndGameById(eventId).orElseThrow(EventService::eventNotFound);
    }

    private static void assertLive(Event event) {
        if (event.getStatus() == Event.EventStatus.COMPLETED) {
            throw ApiException.conflict("EVENT_COMPLETED", "This event has already happened");
        }
        if (event.getStatus() == Event.EventStatus.CANCELLED) {
            throw ApiException.conflict("EVENT_CANCELLED", "This event has been cancelled");
        }
    }

    /** OPEN ↔ FULL from the accepted count; returns whether the status changed. */
    static boolean refreshCapacityStatus(Event event, int accepted) {
        Event.EventStatus status = event.getStatus();
        if (status == Event.EventStatus.OPEN && accepted >= event.getMaxParticipants()) {
            event.setStatus(Event.EventStatus.FULL);
            return true;
        }
        if (status == Event.EventStatus.FULL && accepted < event.getMaxParticipants()) {
            event.setStatus(Event.EventStatus.OPEN);
            return true;
        }
        return false;
    }

    private Game findGame(UUID gameId) {
        return gameRepository.findById(gameId)
                .orElseThrow(() -> ApiException.notFound("GAME_NOT_FOUND", "Game not found"));
    }

    private static boolean isCurrentGame(Event event, UUID gameId) {
        return event.getGame() != null && gameId.equals(event.getGame().getId());
    }

    private void notifyAccepted(Event event, NotificationType type, UUID actorId) {
        for (UUID recipient : participantRepository.findAcceptedUserIds(event.getId())) {
            if (!recipient.equals(actorId)) {
                notify(recipient, type, actorId, event.getId());
            }
        }
    }

    private void notify(UUID recipientId, NotificationType type, UUID actorId, UUID eventId) {
        notificationService.send(recipientId, type, actorId, eventId, REFERENCE_TYPE);
    }

    private void recordActivity(UUID userId, String type, Event event, Instant at) {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("eventId", event.getId());
        data.put("eventTitle", event.getTitle());
        data.put("scheduledAt", event.getScheduledAt());
        data.put("visibility", event.getVisibility().name());
        data.put("gameId", event.getGame() != null ? event.getGame().getId() : null);
        data.put("gameName", event.getGame() != null ? event.getGame().getNameEn() : null);
        eventPublisher.publishEvent(new ActivityRecordedEvent(userId, type, data, at));
    }

    private void publishChanged(UUID eventId) {
        eventPublisher.publishEvent(new EventChanged(eventId));
    }

    private static int clampLimit(int limit) {
        return Math.max(1, Math.min(limit, MAX_LIST_LIMIT));
    }

    private static String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    private static ApiException eventNotFound() {
        return ApiException.notFound("EVENT_NOT_FOUND", "Event not found");
    }

    /** Opaque keyset cursor for the community list: base64url("{scheduledAt ISO}|{id}"). */
    record CommunityCursor(Instant scheduledAt, UUID id) {

        String encode() {
            String raw = scheduledAt + "|" + id;
            return Base64.getUrlEncoder().withoutPadding().encodeToString(raw.getBytes(StandardCharsets.UTF_8));
        }

        static CommunityCursor decode(String cursor) {
            try {
                String raw = new String(Base64.getUrlDecoder().decode(cursor), StandardCharsets.UTF_8);
                int sep = raw.indexOf('|');
                if (sep < 0) {
                    throw invalid();
                }
                return new CommunityCursor(Instant.parse(raw.substring(0, sep)), UUID.fromString(raw.substring(sep + 1)));
            } catch (IllegalArgumentException | DateTimeParseException e) {
                throw invalid();
            }
        }

        private static ApiException invalid() {
            return new ApiException(HttpStatus.BAD_REQUEST, "INVALID_CURSOR", "Invalid cursor");
        }
    }
}
