package com.meeplehearth.post.repository;

import com.meeplehearth.post.entity.PostLike;
import com.meeplehearth.post.entity.PostLikeId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Set;
import java.util.UUID;

@Repository
public interface PostLikeRepository extends JpaRepository<PostLike, PostLikeId> {

    boolean existsById(PostLikeId id);

    Set<PostLikeId> findByIdPostIdInAndIdUserId(Set<UUID> postIds, UUID userId);
}
