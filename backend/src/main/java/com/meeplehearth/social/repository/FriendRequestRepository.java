package com.meeplehearth.social.repository;

import com.meeplehearth.social.entity.FriendRequest;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface FriendRequestRepository extends JpaRepository<FriendRequest, UUID> {

    @EntityGraph(attributePaths = {"sender", "receiver"})
    Optional<FriendRequest> findBySenderIdAndReceiverId(UUID senderId, UUID receiverId);

    @EntityGraph(attributePaths = {"sender", "receiver"})
    Page<FriendRequest> findByReceiverIdAndStatus(UUID receiverId, FriendRequest.Status status, Pageable pageable);

    @EntityGraph(attributePaths = {"sender", "receiver"})
    Page<FriendRequest> findBySenderIdAndStatus(UUID senderId, FriendRequest.Status status, Pageable pageable);

    @Query("""
            SELECT CASE WHEN fr.sender.id = :userId THEN fr.receiver.id ELSE fr.sender.id END
            FROM FriendRequest fr
            WHERE (fr.sender.id = :userId OR fr.receiver.id = :userId)
              AND fr.status = 'ACCEPTED'
            """)
    List<UUID> findFriendIds(UUID userId);

    @EntityGraph(attributePaths = {"sender", "receiver"})
    @Query("""
            SELECT fr FROM FriendRequest fr
            WHERE (fr.sender.id = :userA AND fr.receiver.id = :userB)
               OR (fr.sender.id = :userB AND fr.receiver.id = :userA)
            ORDER BY fr.createdAt DESC
            """)
    List<FriendRequest> findBetween(UUID userA, UUID userB);

    boolean existsBySenderIdAndReceiverIdAndStatus(UUID senderId, UUID receiverId, FriendRequest.Status status);

    long countBySenderIdAndStatus(UUID senderId, FriendRequest.Status status);

    /** Requests between the viewer and any of {@code otherIds}, both directions (search status badges). */
    @Query("""
            SELECT fr FROM FriendRequest fr
            WHERE (fr.sender.id = :viewerId AND fr.receiver.id IN :otherIds)
               OR (fr.receiver.id = :viewerId AND fr.sender.id IN :otherIds)
            """)
    List<FriendRequest> findBetweenViewerAnd(UUID viewerId, Collection<UUID> otherIds);

    /** Removes every pending request the user sent or received (account deletion). */
    @Modifying
    @Query("""
            DELETE FROM FriendRequest fr
            WHERE fr.status = 'PENDING' AND (fr.sender.id = :userId OR fr.receiver.id = :userId)
            """)
    int deletePendingInvolving(UUID userId);

    @Query("""
            SELECT CASE WHEN COUNT(fr) > 0 THEN true ELSE false END FROM FriendRequest fr
            WHERE fr.status = 'ACCEPTED'
              AND ((fr.sender.id = :userA AND fr.receiver.id = :userB)
                OR (fr.sender.id = :userB AND fr.receiver.id = :userA))
            """)
    boolean areFriends(UUID userA, UUID userB);
}
