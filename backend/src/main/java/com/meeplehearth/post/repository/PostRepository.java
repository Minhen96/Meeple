package com.meeplehearth.post.repository;

import com.meeplehearth.post.entity.Post;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface PostRepository extends JpaRepository<Post, UUID> {

    // Friends' feed — no N+1
    @EntityGraph(attributePaths = {"author", "game", "images"})
    @Query("""
            SELECT p FROM Post p
            WHERE p.deletedAt IS NULL
              AND p.author.id IN :friendIds
            ORDER BY p.createdAt DESC
            """)
    Page<Post> findFeedForUser(List<UUID> friendIds, Pageable pageable);

    @EntityGraph(attributePaths = {"author", "game", "images"})
    @Query("SELECT p FROM Post p WHERE p.author.id = :userId AND p.deletedAt IS NULL ORDER BY p.createdAt DESC")
    Page<Post> findByAuthorId(UUID userId, Pageable pageable);
}
