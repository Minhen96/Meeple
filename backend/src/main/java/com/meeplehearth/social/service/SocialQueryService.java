package com.meeplehearth.social.service;

import com.meeplehearth.common.dto.PageMeta;
import com.meeplehearth.common.dto.PageResponse;
import com.meeplehearth.social.dto.SuggestedUser;
import com.meeplehearth.user.dto.UserSummary;
import com.meeplehearth.social.dto.UserSummaryWithStatus;
import com.meeplehearth.social.entity.FriendRequest;
import com.meeplehearth.social.repository.FriendRequestRepository;
import com.meeplehearth.social.repository.SocialUserRepository;
import com.meeplehearth.user.entity.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Read side of the social graph: user search with friendship status, "people you may know"
 * suggestions and the blocked-users list (FEATURES_COMPLETE 2.2, 2.3).
 *
 * <p>The account package's {@code UserController} maps {@code GET /users/search} and
 * {@code GET /users/suggestions} onto {@link #searchWithStatus} and {@link #suggestions}
 * (docs/GAP_ANALYSIS.md section 5, WP3).
 */
@Service
@Transactional(readOnly = true)
public class SocialQueryService {

    static final int MAX_PAGE_SIZE = 50;
    static final int MAX_SUGGESTIONS = 10;

    private final SocialUserRepository socialUserRepository;
    private final FriendRequestRepository friendRequestRepository;

    public SocialQueryService(SocialUserRepository socialUserRepository,
                              FriendRequestRepository friendRequestRepository) {
        this.socialUserRepository = socialUserRepository;
        this.friendRequestRepository = friendRequestRepository;
    }

    /**
     * Users matching {@code q} by username or display name (case-insensitive substring), excluding
     * the viewer, soft-deleted users and anyone blocked either way. An exact username match ranks
     * first. Blank queries return an empty page.
     */
    public PageResponse<UserSummaryWithStatus> searchWithStatus(UUID viewerId, String q, int page, int size) {
        int safeSize = Math.clamp(size, 1, MAX_PAGE_SIZE);
        int safePage = Math.max(page, 0);
        String term = q == null ? "" : q.trim().toLowerCase(Locale.ROOT);
        if (term.isEmpty()) {
            return new PageResponse<>(List.of(), new PageMeta(safePage + 1, safeSize, 0, false));
        }
        Page<User> users = socialUserRepository.searchVisible(viewerId, "%" + escapeLike(term) + "%", term,
                PageRequest.of(safePage, safeSize));
        Map<UUID, String> statuses = friendshipStatuses(viewerId,
                users.getContent().stream().map(User::getId).toList());
        return PageResponse.of(users, u -> UserSummaryWithStatus.of(u, statuses.get(u.getId())));
    }

    /** Convenience for callers that only need the first {@code limit} matches. */
    public List<UserSummaryWithStatus> searchWithStatus(UUID viewerId, String q, int limit) {
        return searchWithStatus(viewerId, q, 0, limit).data();
    }

    /**
     * Up to {@code limit} (max 10) people the viewer may know: users owning games from the viewer's
     * collection, ranked by overlap; topped up with the newest users when there are too few.
     * Friends, pending requests (either direction), blocks (either way), deleted users and the
     * viewer are never suggested.
     */
    public List<SuggestedUser> suggestions(UUID viewerId, int limit) {
        int safeLimit = Math.clamp(limit, 1, MAX_SUGGESTIONS);
        Map<UUID, Long> shared = new LinkedHashMap<>();
        for (Object[] row : socialUserRepository.findSuggestionsByGameOverlap(viewerId, safeLimit)) {
            shared.put((UUID) row[0], ((Number) row[1]).longValue());
        }
        if (shared.size() < safeLimit) {
            // NOT IN () is invalid SQL, so exclude the viewer when nothing else is excluded yet
            Collection<UUID> exclude = shared.isEmpty() ? List.of(viewerId) : shared.keySet();
            socialUserRepository.findNewestSuggestionIds(viewerId, exclude, safeLimit - shared.size())
                    .forEach(id -> shared.putIfAbsent(id, 0L));
        }
        if (shared.isEmpty()) {
            return List.of();
        }
        Map<UUID, User> users = socialUserRepository.findAllByIdIn(shared.keySet()).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));
        return shared.entrySet().stream()
                .map(e -> {
                    User u = users.get(e.getKey());
                    return u == null ? null
                            : new SuggestedUser(u.getId(), u.getUsername(), u.getDisplayName(), u.getAvatarUrl(),
                                    e.getValue());
                })
                .filter(Objects::nonNull)
                .toList();
    }

    /** Users the viewer has blocked, most recent first ({@code GET /users/me/blocked}). */
    public List<UserSummary> blockedUsers(UUID viewerId) {
        return socialUserRepository.findBlockedBy(viewerId).stream().map(UserSummary::from).toList();
    }

    /**
     * The viewer's relationship with each of {@code userIds} in one query:
     * {@code none | pending_sent | pending_received | friends}.
     */
    public Map<UUID, String> friendshipStatuses(UUID viewerId, Collection<UUID> userIds) {
        Map<UUID, String> result = new HashMap<>();
        userIds.forEach(id -> result.put(id, UserSummaryWithStatus.NONE));
        if (userIds.isEmpty()) {
            return result;
        }
        for (FriendRequest fr : friendRequestRepository.findBetweenViewerAnd(viewerId, userIds)) {
            boolean sentByViewer = fr.getSender().getId().equals(viewerId);
            UUID other = sentByViewer ? fr.getReceiver().getId() : fr.getSender().getId();
            String status = switch (fr.getStatus()) {
                case ACCEPTED -> UserSummaryWithStatus.FRIENDS;
                case PENDING -> sentByViewer ? UserSummaryWithStatus.PENDING_SENT
                        : UserSummaryWithStatus.PENDING_RECEIVED;
                case DECLINED -> UserSummaryWithStatus.NONE;
            };
            // An accepted row wins over a stale declined row in the other direction
            if (!UserSummaryWithStatus.NONE.equals(status)) {
                result.put(other, status);
            }
        }
        return result;
    }

    /** Escapes LIKE wildcards so user input matches literally (escape character {@code \}). */
    public static String escapeLike(String term) {
        StringBuilder sb = new StringBuilder(term.length());
        for (char c : term.toCharArray()) {
            if (c == '\\' || c == '%' || c == '_') {
                sb.append('\\');
            }
            sb.append(c);
        }
        return sb.toString();
    }
}
