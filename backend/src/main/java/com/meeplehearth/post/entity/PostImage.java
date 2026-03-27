package com.meeplehearth.post.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.UuidGenerator;

import java.util.UUID;

@Entity
@Table(name = "post_images")
@Getter
@Setter
public class PostImage {

    @Id
    @UuidGenerator
    @Column(updatable = false, nullable = false)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "post_id", nullable = false)
    private Post post;

    @Column(name = "r2_key", nullable = false)
    private String r2Key;

    @Column(name = "sort_order", nullable = false)
    private int sortOrder = 0;
}
