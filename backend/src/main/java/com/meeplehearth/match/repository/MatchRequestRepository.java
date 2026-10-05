package com.meeplehearth.match.repository;

import com.meeplehearth.match.entity.MatchRequest;
import com.meeplehearth.user.entity.User;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface MatchRequestRepository extends JpaRepository<MatchRequest, UUID> {

    @EntityGraph(attributePaths = {"game"})
    List<MatchRequest> findByUserIdAndStatus(UUID userId, MatchRequest.Status status);

    int countByUserIdAndStatus(UUID userId, MatchRequest.Status status);

    @EntityGraph(attributePaths = {"game"})
    Optional<MatchRequest> findByUserIdAndGameIdAndStatus(UUID userId, UUID gameId, MatchRequest.Status status);

    @EntityGraph(attributePaths = {"user", "game"})
    @Query("SELECT mr FROM MatchRequest mr WHERE mr.status = 'ACTIVE'")
    List<MatchRequest> findAllActive();

    /**
     * Row-locks the requesting user so concurrent createRequest calls for the same user are
     * serialised (keeps the active-request limit and the one-ACTIVE-per-game rule race-free).
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT u FROM User u WHERE u.id = :userId AND u.deletedAt IS NULL")
    Optional<User> lockUser(UUID userId);

    /**
     * MATCHED requests of the given groups' members for the group's game, newest first, that
     * can be reactivated: excludes (user, game) pairs that already have a newer ACTIVE request
     * (only one ACTIVE request per user and game is allowed, see V32).
     */
    @Query("""
            SELECT mr FROM MatchRequest mr
            WHERE mr.status = 'MATCHED'
              AND EXISTS (SELECT m FROM MatchGroupMember m
                          WHERE m.group.id IN :groupIds
                            AND m.user.id = mr.user.id
                            AND m.group.game.id = mr.game.id)
              AND NOT EXISTS (SELECT a FROM MatchRequest a
                              WHERE a.status = 'ACTIVE'
                                AND a.user.id = mr.user.id
                                AND a.game.id = mr.game.id)
            ORDER BY mr.createdAt DESC
            """)
    List<MatchRequest> findReactivatableForGroups(Collection<UUID> groupIds);

    /**
     * Conflict-safe reactivation: flips the given MATCHED requests back to ACTIVE in one statement,
     * skipping any (user, game) that already has an ACTIVE request (e.g. one the user created
     * while the scheduler was running), so the partial unique index
     * uq_match_requests_user_game_active is not hit. Callers must pass at most one id per
     * (user, game). Returns the number of rows reactivated.
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(value = """
            UPDATE match_requests m SET status = 'ACTIVE'
            WHERE m.id IN (:ids)
              AND m.status = 'MATCHED'
              AND NOT EXISTS (SELECT 1 FROM match_requests a
                              WHERE a.user_id = m.user_id
                                AND a.game_id = m.game_id
                                AND a.status = 'ACTIVE')
            """, nativeQuery = true)
    int reactivateIfNoActive(Collection<UUID> ids);

    /**
     * Atomically claims ACTIVE requests for a new match group. Returns the number of rows moved
     * to MATCHED; fewer than ids.size() means some were cancelled/matched concurrently.
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(value = "UPDATE match_requests SET status = 'MATCHED' WHERE id IN (:ids) AND status = 'ACTIVE'",
            nativeQuery = true)
    int markMatchedIfActive(Collection<UUID> ids);

    @EntityGraph(attributePaths = {"user", "game"})
    @Query("SELECT mr FROM MatchRequest mr WHERE mr.id IN :ids")
    List<MatchRequest> findAllWithUserAndGameByIdIn(Collection<UUID> ids);

    /** Accepted friendships among users that currently have an ACTIVE request: rows of [senderId, receiverId]. */
    @Query("""
            SELECT fr.sender.id, fr.receiver.id FROM FriendRequest fr
            WHERE fr.status = 'ACCEPTED'
              AND fr.sender.id IN (SELECT a.user.id FROM MatchRequest a WHERE a.status = 'ACTIVE')
              AND fr.receiver.id IN (SELECT b.user.id FROM MatchRequest b WHERE b.status = 'ACTIVE')
            """)
    List<Object[]> findFriendPairsAmongActiveRequesters();

    /** Blocks among users that currently have an ACTIVE request: rows of [blockerId, blockedId]. */
    @Query("""
            SELECT bu.id.blockerId, bu.id.blockedId FROM BlockedUser bu
            WHERE bu.id.blockerId IN (SELECT a.user.id FROM MatchRequest a WHERE a.status = 'ACTIVE')
              AND bu.id.blockedId IN (SELECT b.user.id FROM MatchRequest b WHERE b.status = 'ACTIVE')
            """)
    List<Object[]> findBlockPairsAmongActiveRequesters();
}
