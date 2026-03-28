package com.meeplehearth.post.entity;

import jakarta.persistence.*;

import java.time.Instant;

@Entity
@Table(name = "post_likes")
public class PostLike {

    @EmbeddedId
    private PostLikeId id;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    public PostLike() {}

    public PostLike(PostLikeId id) {
        this.id = id;
    }

    public PostLikeId getId() { return id; }
    public void setId(PostLikeId id) { this.id = id; }
    public Instant getCreatedAt() { return createdAt; }
}
