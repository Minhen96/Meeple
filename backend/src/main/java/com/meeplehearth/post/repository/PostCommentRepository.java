package com.meeplehearth.post.repository;

import com.meeplehearth.post.entity.PostComment;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface PostCommentRepository extends JpaRepository<PostComment, UUID> {

    @EntityGraph(attributePaths = {"author"})
    @Query("SELECT c FROM PostComment c WHERE c.post.id = :postId AND c.deletedAt IS NULL ORDER BY c.createdAt ASC")
    Page<PostComment> findByPostId(UUID postId, Pageable pageable);
}
