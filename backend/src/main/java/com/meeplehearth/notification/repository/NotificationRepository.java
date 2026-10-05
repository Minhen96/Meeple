package com.meeplehearth.notification.repository;

import com.meeplehearth.notification.entity.Notification;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/** Every read excludes soft-deleted rows ({@code deleted_at IS NOT NULL}). */
@Repository
public interface NotificationRepository extends JpaRepository<Notification, UUID> {

    /** Legacy offset page ({@code ?page=&size=}), newest first. */
    @Query("SELECT n FROM Notification n WHERE n.recipient.id = :recipientId AND n.deletedAt IS NULL"
            + " ORDER BY n.createdAt DESC, n.id DESC")
    Page<Notification> findPage(@Param("recipientId") UUID recipientId, Pageable pageable);

    /** First cursor page: the newest {@code limit} rows. */
    @Query(value = "SELECT * FROM notifications WHERE recipient_id = :recipientId AND deleted_at IS NULL"
            + " ORDER BY created_at DESC, id DESC LIMIT :limit", nativeQuery = true)
    List<Notification> findFirstPage(@Param("recipientId") UUID recipientId, @Param("limit") int limit);

    /**
     * Next cursor page: rows strictly older than the cursor {@code (createdAt, id)} in the
     * {@code created_at DESC, id DESC} order, so rows inserted meanwhile never shift the page.
     */
    @Query(value = "SELECT * FROM notifications WHERE recipient_id = :recipientId AND deleted_at IS NULL"
            + " AND (created_at, id) < (:createdAt, :id)"
            + " ORDER BY created_at DESC, id DESC LIMIT :limit", nativeQuery = true)
    List<Notification> findPageBefore(@Param("recipientId") UUID recipientId,
                                      @Param("createdAt") Instant createdAt,
                                      @Param("id") UUID id,
                                      @Param("limit") int limit);

    @Query("SELECT n FROM Notification n WHERE n.id = :id AND n.recipient.id = :recipientId AND n.deletedAt IS NULL")
    Optional<Notification> findOwned(@Param("id") UUID id, @Param("recipientId") UUID recipientId);

    @Query("SELECT COUNT(n) FROM Notification n WHERE n.recipient.id = :recipientId AND n.read = false"
            + " AND n.deletedAt IS NULL")
    long countUnread(@Param("recipientId") UUID recipientId);

    /**
     * The newest live notification of {@code type} about {@code referenceId} for the recipient,
     * created after {@code since} (like batching).
     */
    @Query(value = "SELECT * FROM notifications WHERE recipient_id = :recipientId AND type = :type"
            + " AND reference_id = :referenceId AND deleted_at IS NULL AND created_at > :since"
            + " ORDER BY created_at DESC LIMIT 1", nativeQuery = true)
    Optional<Notification> findRecent(@Param("recipientId") UUID recipientId,
                                      @Param("type") String type,
                                      @Param("referenceId") UUID referenceId,
                                      @Param("since") Instant since);

    /** @return 1 if the row went from unread to read, 0 otherwise */
    @Modifying
    @Query("UPDATE Notification n SET n.read = true WHERE n.id = :id AND n.recipient.id = :recipientId"
            + " AND n.read = false AND n.deletedAt IS NULL")
    int markRead(@Param("id") UUID id, @Param("recipientId") UUID recipientId);

    @Modifying
    @Query("UPDATE Notification n SET n.read = true WHERE n.recipient.id = :recipientId AND n.read = false"
            + " AND n.deletedAt IS NULL")
    int markAllReadForUser(@Param("recipientId") UUID recipientId);

    @Modifying
    @Query("UPDATE Notification n SET n.pushed = true WHERE n.id = :id")
    int markPushed(@Param("id") UUID id);

    /** Every notification the user received (account deletion). */
    @Modifying
    @Query(value = "DELETE FROM notifications WHERE recipient_id = :userId", nativeQuery = true)
    int deleteAllForRecipient(@Param("userId") UUID userId);

    /** Every notification the user triggered for someone else (account hard delete). */
    @Modifying
    @Query(value = "DELETE FROM notifications WHERE actor_id = :userId", nativeQuery = true)
    int deleteAllByActor(@Param("userId") UUID userId);

    /**
     * Retention: one batch of rows created before {@code createdBefore}, or soft-deleted before
     * {@code deletedBefore}.
     */
    @Modifying
    @Query(value = "DELETE FROM notifications WHERE id IN (SELECT id FROM notifications"
            + " WHERE created_at < :createdBefore OR deleted_at < :deletedBefore LIMIT :batchSize)",
            nativeQuery = true)
    int deleteExpiredBatch(@Param("createdBefore") Instant createdBefore,
                           @Param("deletedBefore") Instant deletedBefore,
                           @Param("batchSize") int batchSize);
}
