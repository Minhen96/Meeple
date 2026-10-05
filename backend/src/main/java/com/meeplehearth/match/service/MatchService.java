package com.meeplehearth.match.service;

import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.event.dto.CreateEventRequest;
import com.meeplehearth.event.dto.EventResponse;
import com.meeplehearth.event.service.EventService;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.match.dto.CreateMatchRequestDto;
import com.meeplehearth.match.dto.MatchGroupResponse;
import com.meeplehearth.match.dto.MatchRequestResponse;
import com.meeplehearth.match.entity.*;
import com.meeplehearth.match.repository.MatchGroupRepository;
import com.meeplehearth.match.repository.MatchRequestRepository;
import com.meeplehearth.notification.entity.Notification;
import com.meeplehearth.notification.service.NotificationService;
import com.meeplehearth.user.entity.User;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class MatchService {

    private static final Logger log = LoggerFactory.getLogger(MatchService.class);
    private static final int MAX_ACTIVE_REQUESTS = 5;
    static final String ACTIVE_UNIQUE_INDEX = "uq_match_requests_user_game_active";

    private final MatchRequestRepository matchRequestRepository;
    private final MatchGroupRepository matchGroupRepository;
    private final GameRepository gameRepository;
    private final NotificationService notificationService;
    private final EventService eventService;
    private final TransactionTemplate transactionTemplate;

    public MatchService(MatchRequestRepository matchRequestRepository,
                        MatchGroupRepository matchGroupRepository,
                        GameRepository gameRepository,
                        NotificationService notificationService,
                        EventService eventService,
                        PlatformTransactionManager transactionManager) {
        this.transactionTemplate = new TransactionTemplate(transactionManager);
        this.matchRequestRepository = matchRequestRepository;
        this.matchGroupRepository = matchGroupRepository;
        this.gameRepository = gameRepository;
        this.notificationService = notificationService;
        this.eventService = eventService;
    }

    // -------------------------------------------------------------------------
    // Create match request
    // -------------------------------------------------------------------------

    /**
     * Creates (or idempotently updates) the caller's ACTIVE request for a game. The scheduler can
     * reactivate an older request for the same game between our existence check and the insert;
     * the insert then hits the partial unique index, so the whole upsert is retried once in a
     * fresh transaction, where it finds and updates that ACTIVE row instead of failing with a 500.
     */
    public MatchRequestResponse createRequest(UUID userId, CreateMatchRequestDto dto) {
        // Validate time window
        if (dto.availableFrom() != null && dto.availableTo() != null) {
            if (!dto.availableFrom().isBefore(dto.availableTo())) {
                throw ApiException.badRequest("INVALID_TIME", "availableFrom must be before availableTo");
            }
            if (dto.availableTo().isAfter(Instant.now().plus(7, ChronoUnit.DAYS))) {
                throw ApiException.badRequest("INVALID_TIME", "availableTo cannot be more than 7 days in the future");
            }
        }

        try {
            return transactionTemplate.execute(status -> upsertRequest(userId, dto));
        } catch (DataIntegrityViolationException e) {
            if (!isActiveUniqueViolation(e)) {
                throw e;
            }
            log.info("Match request insert raced with a reactivation; retrying as update");
        }
        try {
            return transactionTemplate.execute(status -> upsertRequest(userId, dto));
        } catch (DataIntegrityViolationException e) {
            if (!isActiveUniqueViolation(e)) {
                throw e;
            }
            throw ApiException.conflict("MATCH_REQUEST_CONFLICT", "Match request was modified concurrently, please retry");
        }
    }

    private MatchRequestResponse upsertRequest(UUID userId, CreateMatchRequestDto dto) {
        var game = gameRepository.findById(dto.gameId())
                .orElseThrow(() -> ApiException.notFound("GAME_NOT_FOUND", "Game not found"));

        // Serialise concurrent creates for this user (row lock held until commit)
        User user = matchRequestRepository.lockUser(userId)
                .orElseThrow(() -> ApiException.notFound("USER_NOT_FOUND", "User not found"));

        // Idempotent upsert: if an active request already exists for this game, update time window
        Optional<MatchRequest> existing = matchRequestRepository
                .findByUserIdAndGameIdAndStatus(userId, dto.gameId(), MatchRequest.Status.ACTIVE);
        if (existing.isPresent()) {
            MatchRequest mr = existing.get();
            mr.setAvailableFrom(dto.availableFrom());
            mr.setAvailableTo(dto.availableTo());
            return MatchRequestResponse.from(matchRequestRepository.save(mr));
        }

        // Max active requests (only applies when creating a new one)
        if (matchRequestRepository.countByUserIdAndStatus(userId, MatchRequest.Status.ACTIVE) >= MAX_ACTIVE_REQUESTS) {
            throw ApiException.badRequest("TOO_MANY_REQUESTS", "Maximum " + MAX_ACTIVE_REQUESTS + " active match requests allowed");
        }

        MatchRequest mr = new MatchRequest();
        mr.setUser(user);
        mr.setGame(game);
        mr.setAvailableFrom(dto.availableFrom());
        mr.setAvailableTo(dto.availableTo());
        // Flush now so a unique-index violation surfaces here (translated), not at commit
        return MatchRequestResponse.from(matchRequestRepository.saveAndFlush(mr));
    }

    static boolean isActiveUniqueViolation(Throwable e) {
        for (Throwable t = e; t != null; t = t.getCause()) {
            String msg = t.getMessage();
            if (msg != null && msg.contains(ACTIVE_UNIQUE_INDEX)) {
                return true;
            }
        }
        return false;
    }

    // -------------------------------------------------------------------------
    // Cancel
    // -------------------------------------------------------------------------

    @Transactional
    public void cancelRequest(UUID userId, UUID requestId) {
        MatchRequest mr = matchRequestRepository.findById(requestId)
                .orElseThrow(() -> ApiException.notFound("REQUEST_NOT_FOUND", "Match request not found"));
        if (!mr.getUser().getId().equals(userId)) {
            throw ApiException.forbidden("FORBIDDEN", "Not your match request");
        }
        mr.setStatus(MatchRequest.Status.CANCELLED);
        matchRequestRepository.save(mr);
    }

    // -------------------------------------------------------------------------
    // List mine
    // -------------------------------------------------------------------------

    public List<MatchRequestResponse> listMyRequests(UUID userId) {
        return matchRequestRepository.findByUserIdAndStatus(userId, MatchRequest.Status.ACTIVE)
                .stream().map(MatchRequestResponse::from).toList();
    }

    // -------------------------------------------------------------------------
    // Suggestions (pending match groups)
    // -------------------------------------------------------------------------

    public List<MatchGroupResponse> getSuggestions(UUID userId) {
        return matchGroupRepository.findPendingForUser(userId)
                .stream().map(MatchGroupResponse::from).toList();
    }

    // -------------------------------------------------------------------------
    // Accept match → create event
    // -------------------------------------------------------------------------

    @Transactional
    public EventResponse acceptMatch(UUID userId, UUID groupId) {
        MatchGroup group = findPendingGroup(groupId);
        assertMember(group, userId);

        // Build event from match group — host is the accepting user
        CreateEventRequest req = new CreateEventRequest(
                group.getGame().getNameEn() + " Night",
                null,
                null,
                group.getOverlapStart() != null ? group.getOverlapStart() : Instant.now().plus(1, ChronoUnit.DAYS),
                group.getGame().getId(),
                group.getGame().getMaxPlayers() != null ? group.getGame().getMaxPlayers() : 8,
                "FRIENDS"
        );

        EventResponse event = eventService.createEvent(userId, req);

        group.setStatus(MatchGroup.Status.ACCEPTED);
        matchGroupRepository.save(group);

        // Notify other members
        for (MatchGroupMember m : group.getMembers()) {
            if (!m.getUser().getId().equals(userId)) {
                notificationService.send(
                        m.getUser().getId(),
                        Notification.NotificationType.EVENT_INVITE,
                        userId,
                        event.id(),
                        "EVENT"
                );
            }
        }
        return event;
    }

    // -------------------------------------------------------------------------
    // Dismiss match
    // -------------------------------------------------------------------------

    @Transactional
    public void dismissMatch(UUID userId, UUID groupId) {
        MatchGroup group = findPendingGroup(groupId);
        MatchGroupMember member = assertMember(group, userId);

        member.setStatus(MatchGroupMember.MemberStatus.DISMISSED);
        matchGroupRepository.save(group);

        // If all members dismissed → dismiss group and reactivate requests
        boolean allDismissed = group.getMembers().stream()
                .allMatch(m -> m.getStatus() == MatchGroupMember.MemberStatus.DISMISSED);

        if (allDismissed) {
            group.setStatus(MatchGroup.Status.DISMISSED);
            matchGroupRepository.save(group);

            reactivateRequests(List.of(group.getId()));
        }
    }

    // -------------------------------------------------------------------------
    // Matching algorithm (called by scheduler)
    // -------------------------------------------------------------------------

    /**
     * Not transactional as a whole: expiring each stale group and creating each new group run in
     * their own transactions, so one failure (e.g. a unique-index race with a concurrent
     * createRequest) only skips that group instead of rolling back the whole run.
     */
    public void runMatchingAlgorithm() {
        expireOldGroups();

        List<MatchRequest> activeRequests = matchRequestRepository.findAllActive();
        if (activeRequests.isEmpty()) return;

        // Build friend set for fast lookup: key = sorted pair "a:b"
        Set<String> friendPairs = buildFriendPairSet();
        Set<String> blockPairs = buildBlockPairSet();

        // Group requests by game
        Map<UUID, List<MatchRequest>> byGame = activeRequests.stream()
                .collect(Collectors.groupingBy(mr -> mr.getGame().getId()));

        for (Map.Entry<UUID, List<MatchRequest>> entry : byGame.entrySet()) {
            List<MatchRequest> requests = entry.getValue();
            if (requests.size() < 2) continue;

            processGameRequests(requests, friendPairs, blockPairs);
        }
    }

    private void processGameRequests(List<MatchRequest> requests,
                                     Set<String> friendPairs, Set<String> blockPairs) {
        // Find all compatible pairs
        // Use Union-Find to build groups from compatible pairs
        Map<UUID, UUID> parent = new HashMap<>();
        for (MatchRequest r : requests) parent.put(r.getUser().getId(), r.getUser().getId());

        for (int i = 0; i < requests.size(); i++) {
            for (int j = i + 1; j < requests.size(); j++) {
                MatchRequest a = requests.get(i);
                MatchRequest b = requests.get(j);
                UUID ua = a.getUser().getId();
                UUID ub = b.getUser().getId();

                if (!a.overlapsWith(b)) continue;
                if (!areMutualFriends(ua, ub, friendPairs)) continue;
                if (isBlocked(ua, ub, blockPairs)) continue;

                union(parent, ua, ub);
            }
        }

        // Group requests by root
        Map<UUID, List<MatchRequest>> groups = new HashMap<>();
        for (MatchRequest r : requests) {
            UUID root = find(parent, r.getUser().getId());
            groups.computeIfAbsent(root, k -> new ArrayList<>()).add(r);
        }

        for (List<MatchRequest> group : groups.values()) {
            if (group.size() < 2) continue;

            // Check min_players requirement
            Integer minPlayers = group.get(0).getGame().getMinPlayers();
            if (minPlayers != null && group.size() < minPlayers) continue;

            createMatchGroupInOwnTransaction(group.stream().map(MatchRequest::getId).toList());
        }
    }

    private void createMatchGroupInOwnTransaction(List<UUID> requestIds) {
        try {
            transactionTemplate.executeWithoutResult(status -> {
                // Atomically claim the requests; if any was cancelled/matched since the snapshot,
                // undo the claim and skip this group (it is retried on the next run)
                if (matchRequestRepository.markMatchedIfActive(requestIds) != requestIds.size()) {
                    status.setRollbackOnly();
                    log.debug("Skipping match group: requests changed since snapshot");
                    return;
                }
                createMatchGroup(matchRequestRepository.findAllWithUserAndGameByIdIn(requestIds));
            });
        } catch (RuntimeException e) {
            log.error("Failed to create match group for {} requests", requestIds.size(), e);
        }
    }

    /** Persists a group for requests already claimed as MATCHED and notifies the members. */
    private void createMatchGroup(List<MatchRequest> requests) {
        // Compute overlap window
        Instant overlapStart = requests.stream()
                .map(MatchRequest::getAvailableFrom)
                .filter(Objects::nonNull)
                .max(Comparator.naturalOrder())
                .orElse(null);
        Instant overlapEnd = requests.stream()
                .map(MatchRequest::getAvailableTo)
                .filter(Objects::nonNull)
                .min(Comparator.naturalOrder())
                .orElse(null);

        MatchGroup group = new MatchGroup();
        group.setGame(requests.get(0).getGame());
        group.setOverlapStart(overlapStart);
        group.setOverlapEnd(overlapEnd);

        MatchGroup saved = matchGroupRepository.save(group);

        for (MatchRequest r : requests) {
            MatchGroupMember member = new MatchGroupMember();
            member.setId(new MatchGroupMemberId(saved.getId(), r.getUser().getId()));
            member.setGroup(saved);
            member.setUser(r.getUser());
            saved.getMembers().add(member);
        }

        matchGroupRepository.save(saved);

        // Notify all members
        for (MatchRequest r : requests) {
            notificationService.send(
                    r.getUser().getId(),
                    Notification.NotificationType.MATCH_FOUND,
                    null,
                    saved.getId(),
                    "MATCH_GROUP"
            );
        }

        log.info("Created match group {} for game {} with {} members",
                saved.getId(), saved.getGame().getNameEn(), requests.size());
    }

    /** Expires each stale PENDING group (and reactivates its requests) in its own transaction. */
    private void expireOldGroups() {
        Instant now = Instant.now();
        Instant cutoff = now.minus(48, ChronoUnit.HOURS);
        for (UUID groupId : matchGroupRepository.findExpiredGroupIds(cutoff)) {
            try {
                transactionTemplate.executeWithoutResult(status -> {
                    // Skip if accepted/dismissed since the id list was read
                    if (matchGroupRepository.expireIfPending(groupId, now) == 1) {
                        reactivateRequests(List.of(groupId));
                    }
                });
            } catch (RuntimeException e) {
                log.error("Failed to expire match group {}", groupId, e);
            }
        }
    }

    /**
     * Puts the groups' members' MATCHED requests back to ACTIVE. At most one request per
     * (user, game) is chosen (the newest), and the UPDATE itself skips any (user, game) that
     * already has an ACTIVE request, so a request the user created concurrently wins and the
     * one-ACTIVE-per-game unique index is not violated.
     */
    private void reactivateRequests(List<UUID> groupIds) {
        Set<String> seen = new HashSet<>();
        List<UUID> ids = matchRequestRepository.findReactivatableForGroups(groupIds).stream()
                .filter(mr -> seen.add(mr.getUser().getId() + ":" + mr.getGame().getId()))
                .map(MatchRequest::getId)
                .toList();
        if (!ids.isEmpty()) {
            matchRequestRepository.reactivateIfNoActive(ids);
        }
    }

    // -------------------------------------------------------------------------
    // Union-Find helpers
    // -------------------------------------------------------------------------

    private UUID find(Map<UUID, UUID> parent, UUID id) {
        if (!parent.get(id).equals(id)) {
            parent.put(id, find(parent, parent.get(id)));
        }
        return parent.get(id);
    }

    private void union(Map<UUID, UUID> parent, UUID a, UUID b) {
        UUID ra = find(parent, a);
        UUID rb = find(parent, b);
        if (!ra.equals(rb)) parent.put(ra, rb);
    }

    // -------------------------------------------------------------------------
    // Friend / block helpers
    // -------------------------------------------------------------------------

    // Only pairs among users with an ACTIVE request are loaded, never the whole tables
    private Set<String> buildFriendPairSet() {
        return matchRequestRepository.findFriendPairsAmongActiveRequesters().stream()
                .map(row -> pairKey((UUID) row[0], (UUID) row[1]))
                .collect(Collectors.toSet());
    }

    private Set<String> buildBlockPairSet() {
        return matchRequestRepository.findBlockPairsAmongActiveRequesters().stream()
                .map(row -> pairKey((UUID) row[0], (UUID) row[1]))
                .collect(Collectors.toSet());
    }

    private boolean areMutualFriends(UUID a, UUID b, Set<String> friendPairs) {
        return friendPairs.contains(pairKey(a, b));
    }

    private boolean isBlocked(UUID a, UUID b, Set<String> blockPairs) {
        String key = a.toString() + ":" + b.toString();
        String keyRev = b.toString() + ":" + a.toString();
        return blockPairs.contains(key) || blockPairs.contains(keyRev);
    }

    private String pairKey(UUID a, UUID b) {
        // Sorted so a:b == b:a for mutual friend check
        return a.compareTo(b) < 0
                ? a.toString() + ":" + b.toString()
                : b.toString() + ":" + a.toString();
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private MatchGroup findPendingGroup(UUID groupId) {
        MatchGroup group = matchGroupRepository.findById(groupId)
                .orElseThrow(() -> ApiException.notFound("GROUP_NOT_FOUND", "Match group not found"));
        if (group.getStatus() != MatchGroup.Status.PENDING) {
            throw ApiException.badRequest("GROUP_NOT_PENDING", "Match group is no longer pending");
        }
        return group;
    }

    private MatchGroupMember assertMember(MatchGroup group, UUID userId) {
        return group.getMembers().stream()
                .filter(m -> m.getUser().getId().equals(userId))
                .findFirst()
                .orElseThrow(() -> ApiException.forbidden("NOT_MEMBER", "You are not a member of this match group"));
    }
}
