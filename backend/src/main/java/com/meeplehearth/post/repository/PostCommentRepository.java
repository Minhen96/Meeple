package com.meeplehearth.post.repository;

import com.meeplehearth.post.entity.PostComment;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import com.meeplehearth.user.entity.User;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface PostCommentRepository extends JpaRepository<PostComment, UUID> {

    /**
     * Comments visible to the viewer: excludes deleted comments and authors blocked either way.
     * Comments of deleted accounts stay (FEATURES_COMPLETE section 1.6) and render as "Deleted
     * User"; after the hard delete their author is NULL, which never matches a block row.
     * {@code c.author.id} is the foreign-key column, so no join (that would drop NULL authors).
     */
    String VISIBLE_COMMENTS = """
            c.post.id = :postId AND c.deletedAt IS NULL
            AND NOT EXISTS (SELECT bu FROM BlockedUser bu
                            WHERE (bu.id.blockerId = :viewerId AND bu.id.blockedId = c.author.id)
                               OR (bu.id.blockerId = c.author.id AND bu.id.blockedId = :viewerId))
            """;

    @EntityGraph(attributePaths = {"author"})
    @Query(value = "SELECT c FROM PostComment c WHERE " + VISIBLE_COMMENTS + " ORDER BY c.createdAt ASC, c.id ASC",
            countQuery = "SELECT COUNT(c) FROM PostComment c WHERE " + VISIBLE_COMMENTS)
    Page<PostComment> findVisibleByPostId(UUID postId, UUID viewerId, Pageable pageable);

    /**
     * Keyset page of visible comments, oldest first, strictly after {@code (afterTime, afterId)}.
     * The first page passes {@link java.time.Instant#EPOCH} and the all-zero UUID.
     */
    @EntityGraph(attributePaths = {"author"})
    @Query("SELECT c FROM PostComment c WHERE " + VISIBLE_COMMENTS
            + " AND (c.createdAt > :afterTime OR (c.createdAt = :afterTime AND c.id > :afterId))"
            + " ORDER BY c.createdAt ASC, c.id ASC")
    List<PostComment> findVisibleAfter(UUID postId, UUID viewerId, Instant afterTime, UUID afterId,
                                       Pageable pageable);

    /** A comment that is not deleted, with its author (null if hard-deleted) and post (and the post's author). */
    @Query("""
            SELECT c FROM PostComment c LEFT JOIN FETCH c.author JOIN FETCH c.post p JOIN FETCH p.author
            WHERE c.id = :commentId AND c.post.id = :postId AND c.deletedAt IS NULL
            """)
    Optional<PostComment> findActive(UUID postId, UUID commentId);

    /** Active users by lower-case username, for {@code @mention} resolution. */
    @Query("SELECT u FROM User u WHERE LOWER(u.username) IN :usernames AND u.deletedAt IS NULL")
    List<User> findActiveUsersByUsernames(Collection<String> usernames);
}
