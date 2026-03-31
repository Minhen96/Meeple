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
import com.meeplehearth.social.repository.BlockRepository;
import com.meeplehearth.social.repository.FriendRequestRepository;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class MatchService {

    private static final Logger log = LoggerFactory.getLogger(MatchService.class);
    private static final int MAX_ACTIVE_REQUESTS = 5;

    private final MatchRequestRepository matchRequestRepository;
    private final MatchGroupRepository matchGroupRepository;
    private final UserRepository userRepository;
    private final GameRepository gameRepository;
    private final FriendRequestRepository friendRequestRepository;
    private final BlockRepository blockRepository;
    private final NotificationService notificationService;
    private final EventService eventService;

    public MatchService(MatchRequestRepository matchRequestRepository,
                        MatchGroupRepository matchGroupRepository,
                        UserRepository userRepository,
                        GameRepository gameRepository,
                        FriendRequestRepository friendRequestRepository,
                        BlockRepository blockRepository,
                        NotificationService notificationService,
                        EventService eventService) {
        this.matchRequestRepository = matchRequestRepository;
        this.matchGroupRepository = matchGroupRepository;
        this.userRepository = userRepository;
        this.gameRepository = gameRepository;
        this.friendRequestRepository = friendRequestRepository;
        this.blockRepository = blockRepository;
        this.notificationService = notificationService;
        this.eventService = eventService;
    }

    // -------------------------------------------------------------------------
    // Create match request
    // -------------------------------------------------------------------------

    @Transactional
    public MatchRequestResponse createRequest(UUID userId, CreateMatchRequestDto dto) {
        // Max active requests
        if (matchRequestRepository.countByUserIdAndStatus(userId, MatchRequest.Status.ACTIVE) >= MAX_ACTIVE_REQUESTS) {
            throw ApiException.badRequest("TOO_MANY_REQUESTS", "Maximum " + MAX_ACTIVE_REQUESTS + " active match requests allowed");
        }

        // Validate time window
        if (dto.availableFrom() != null && dto.availableTo() != null) {
            if (!dto.availableFrom().isBefore(dto.availableTo())) {
                throw ApiException.badRequest("INVALID_TIME", "availableFrom must be before availableTo");
            }
            if (dto.availableTo().isAfter(Instant.now().plus(7, ChronoUnit.DAYS))) {
                throw ApiException.badRequest("INVALID_TIME", "availableTo cannot be more than 7 days in the future");
            }
        }

        var game = gameRepository.findById(dto.gameId())
                .orElseThrow(() -> ApiException.notFound("GAME_NOT_FOUND", "Game not found"));

        // Upsert: if an active request already exists for this game, update time window
        Optional<MatchRequest> existing = matchRequestRepository
                .findByUserIdAndGameIdAndStatus(userId, dto.gameId(), MatchRequest.Status.ACTIVE);
        if (existing.isPresent()) {
            MatchRequest mr = existing.get();
            mr.setAvailableFrom(dto.availableFrom());
            mr.setAvailableTo(dto.availableTo());
            return MatchRequestResponse.from(matchRequestRepository.save(mr));
        }

        User user = userRepository.getReferenceById(userId);
        MatchRequest mr = new MatchRequest();
        mr.setUser(user);
        mr.setGame(game);
        mr.setAvailableFrom(dto.availableFrom());
        mr.setAvailableTo(dto.availableTo());
        return MatchRequestResponse.from(matchRequestRepository.save(mr));
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

            group.getMembers().forEach(m -> {
                matchRequestRepository
                        .findByUserIdAndGameIdAndStatus(m.getUser().getId(), group.getGame().getId(), MatchRequest.Status.MATCHED)
                        .ifPresent(mr -> {
                            mr.setStatus(MatchRequest.Status.ACTIVE);
                            matchRequestRepository.save(mr);
                        });
            });
        }
    }

    // -------------------------------------------------------------------------
    // Matching algorithm (called by scheduler)
    // -------------------------------------------------------------------------

    @Transactional
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

            createMatchGroup(group);
        }
    }

    private void createMatchGroup(List<MatchRequest> requests) {
        // Check none are already matched to avoid duplicate groups
        boolean anyAlreadyMatched = requests.stream()
                .anyMatch(r -> r.getStatus() == MatchRequest.Status.MATCHED);
        if (anyAlreadyMatched) return;

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

            r.setStatus(MatchRequest.Status.MATCHED);
            matchRequestRepository.save(r);
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

    private void expireOldGroups() {
        Instant cutoff = Instant.now().minus(48, ChronoUnit.HOURS);
        List<MatchGroup> expired = matchGroupRepository.findExpiredGroups(cutoff);
        for (MatchGroup g : expired) {
            g.setStatus(MatchGroup.Status.EXPIRED);
            matchGroupRepository.save(g);
            // Reactivate requests
            g.getMembers().forEach(m ->
                    matchRequestRepository
                            .findByUserIdAndGameIdAndStatus(m.getUser().getId(), g.getGame().getId(), MatchRequest.Status.MATCHED)
                            .ifPresent(mr -> {
                                mr.setStatus(MatchRequest.Status.ACTIVE);
                                matchRequestRepository.save(mr);
                            })
            );
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

    private Set<String> buildFriendPairSet() {
        return friendRequestRepository.findAll().stream()
                .filter(fr -> fr.getStatus() == com.meeplehearth.social.entity.FriendRequest.Status.ACCEPTED)
                .map(fr -> pairKey(fr.getSender().getId(), fr.getReceiver().getId()))
                .collect(Collectors.toSet());
    }

    private Set<String> buildBlockPairSet() {
        return blockRepository.findAll().stream()
                .map(b -> pairKey(b.getId().getBlockerId(), b.getId().getBlockedId()))
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
