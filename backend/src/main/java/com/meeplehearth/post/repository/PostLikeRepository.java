package com.meeplehearth.post.repository;

import com.meeplehearth.post.entity.PostLike;
import com.meeplehearth.post.entity.PostLikeId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.stereotype.Repository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.Set;
import java.util.UUID;

@Repository
public interface PostLikeRepository extends JpaRepository<PostLike, PostLikeId> {

    boolean existsById(PostLikeId id);

    @Query("SELECT pl.id FROM PostLike pl WHERE pl.id.postId IN :postIds AND pl.id.userId = :userId")
    Set<PostLikeId> findLikedPostIds(@Param("postIds") Set<UUID> postIds, @Param("userId") UUID userId);

    /** Idempotent like: returns 1 if a row was inserted, 0 if the user had already liked the post. */
    @Modifying
    @Query(value = """
            INSERT INTO post_likes (post_id, user_id, created_at)
            VALUES (:postId, :userId, NOW())
            ON CONFLICT DO NOTHING
            """, nativeQuery = true)
    int insertIfAbsent(@Param("postId") UUID postId, @Param("userId") UUID userId);

    /** Returns the number of rows deleted (0 or 1). */
    @Modifying
    @Query("DELETE FROM PostLike pl WHERE pl.id.postId = :postId AND pl.id.userId = :userId")
    int deleteByPostIdAndUserId(@Param("postId") UUID postId, @Param("userId") UUID userId);
}
