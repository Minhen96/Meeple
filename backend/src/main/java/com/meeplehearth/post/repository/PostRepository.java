package com.meeplehearth.post.repository;

import com.meeplehearth.post.entity.Post;
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
public interface PostRepository extends JpaRepository<Post, UUID> {

    /** Hides posts whose author and the viewer {@code :viewerId} have blocked each other (alias {@code p}). */
    String NOT_BLOCKED_WITH_VIEWER = """
            NOT EXISTS (SELECT bu FROM BlockedUser bu
                        WHERE (bu.id.blockerId = :viewerId AND bu.id.blockedId = p.author.id)
                           OR (bu.id.blockerId = p.author.id AND bu.id.blockedId = :viewerId))
            """;

    // -------------------------------------------------------------------------
    // Paging is done on IDs only (no collection fetch + Pageable → no in-memory paging);
    // the page's posts are then loaded with findWithDetailsByIdIn + fetchTagsByIdIn.
    // -------------------------------------------------------------------------

    @Query(value = "SELECT p.id FROM Post p"
            + " WHERE p.deletedAt IS NULL AND p.author.deletedAt IS NULL AND p.author.id IN :authorIds"
            + " AND " + NOT_BLOCKED_WITH_VIEWER
            + " ORDER BY p.createdAt DESC, p.id DESC",
            countQuery = "SELECT COUNT(p) FROM Post p"
            + " WHERE p.deletedAt IS NULL AND p.author.deletedAt IS NULL AND p.author.id IN :authorIds"
            + " AND " + NOT_BLOCKED_WITH_VIEWER)
    Page<UUID> findFeedPostIds(Collection<UUID> authorIds, UUID viewerId, Pageable pageable);

    @Query(value = "SELECT p.id FROM Post p"
            + " WHERE p.author.id = :authorId AND p.deletedAt IS NULL AND p.author.deletedAt IS NULL"
            + " ORDER BY p.createdAt DESC, p.id DESC",
            countQuery = "SELECT COUNT(p) FROM Post p"
            + " WHERE p.author.id = :authorId AND p.deletedAt IS NULL AND p.author.deletedAt IS NULL")
    Page<UUID> findPostIdsByAuthorId(UUID authorId, Pageable pageable);

    /** Loads posts with author, game and images in one query. Order is NOT guaranteed. */
    @Query("""
            SELECT DISTINCT p FROM Post p
            JOIN FETCH p.author
            LEFT JOIN FETCH p.game
            LEFT JOIN FETCH p.images
            WHERE p.id IN :ids
            """)
    List<Post> findWithDetailsByIdIn(Collection<UUID> ids);

    /**
     * Initialises the tags collection (and tagged users) of already-loaded posts.
     * Separate from findWithDetailsByIdIn because two bag fetches cannot share one query.
     */
    @Query("""
            SELECT DISTINCT p FROM Post p
            LEFT JOIN FETCH p.tags t
            LEFT JOIN FETCH t.user
            WHERE p.id IN :ids
            """)
    List<Post> fetchTagsByIdIn(Collection<UUID> ids);

    @EntityGraph(attributePaths = {"author", "game"})
    @Query("SELECT p FROM Post p WHERE p.id = :postId AND p.deletedAt IS NULL AND p.author.deletedAt IS NULL")
    Optional<Post> findActiveById(UUID postId);

    // Used by the activity timeline; images/tags are batch-loaded via @BatchSize on Post
    @EntityGraph(attributePaths = {"author", "game"})
    @Query(value = "SELECT p FROM Post p WHERE p.author.id = :userId AND p.deletedAt IS NULL"
            + " AND p.author.deletedAt IS NULL ORDER BY p.createdAt DESC",
            countQuery = "SELECT COUNT(p) FROM Post p WHERE p.author.id = :userId AND p.deletedAt IS NULL"
            + " AND p.author.deletedAt IS NULL")
    Page<Post> findByAuthorId(UUID userId, Pageable pageable);

    // -------------------------------------------------------------------------
    // Atomic counter updates
    // -------------------------------------------------------------------------

    @Modifying
    @Query(value = "UPDATE posts SET like_count = like_count + 1 WHERE id = :postId", nativeQuery = true)
    int incrementLikeCount(UUID postId);

    @Modifying
    @Query(value = "UPDATE posts SET like_count = GREATEST(like_count - 1, 0) WHERE id = :postId", nativeQuery = true)
    int decrementLikeCount(UUID postId);

    @Modifying
    @Query(value = "UPDATE posts SET comment_count = comment_count + 1 WHERE id = :postId", nativeQuery = true)
    int incrementCommentCount(UUID postId);
}
