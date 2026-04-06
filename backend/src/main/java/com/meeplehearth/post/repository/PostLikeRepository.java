package com.meeplehearth.post.repository;

import com.meeplehearth.post.entity.PostLike;
import com.meeplehearth.post.entity.PostLikeId;
import org.springframework.data.jpa.repository.JpaRepository;
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
}
