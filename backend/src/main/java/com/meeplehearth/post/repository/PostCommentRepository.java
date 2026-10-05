package com.meeplehearth.post.repository;

import com.meeplehearth.post.entity.PostComment;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import com.meeplehearth.user.entity.User;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface PostCommentRepository extends JpaRepository<PostComment, UUID> {

    /** Comments visible to the viewer: excludes deleted comments, deleted authors and blocked authors. */
    String VISIBLE_COMMENTS = """
            c.post.id = :postId AND c.deletedAt IS NULL AND c.author.deletedAt IS NULL
            AND NOT EXISTS (SELECT bu FROM BlockedUser bu
                            WHERE (bu.id.blockerId = :viewerId AND bu.id.blockedId = c.author.id)
                               OR (bu.id.blockerId = c.author.id AND bu.id.blockedId = :viewerId))
            """;

    @EntityGraph(attributePaths = {"author"})
    @Query(value = "SELECT c FROM PostComment c WHERE " + VISIBLE_COMMENTS + " ORDER BY c.createdAt ASC, c.id ASC",
            countQuery = "SELECT COUNT(c) FROM PostComment c WHERE " + VISIBLE_COMMENTS)
    Page<PostComment> findVisibleByPostId(UUID postId, UUID viewerId, Pageable pageable);

    /** A comment that is not deleted, with its author and post (and the post's author). */
    @Query("""
            SELECT c FROM PostComment c JOIN FETCH c.author JOIN FETCH c.post p JOIN FETCH p.author
            WHERE c.id = :commentId AND c.post.id = :postId AND c.deletedAt IS NULL
            """)
    Optional<PostComment> findActive(UUID postId, UUID commentId);

    /** Active users by lower-case username, for {@code @mention} resolution. */
    @Query("SELECT u FROM User u WHERE LOWER(u.username) IN :usernames AND u.deletedAt IS NULL")
    List<User> findActiveUsersByUsernames(Collection<String> usernames);
}
