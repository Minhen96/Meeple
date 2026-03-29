package com.meeplehearth.match.entity;

import com.meeplehearth.user.entity.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

@Entity
@Table(name = "match_group_members")
@Getter
@Setter
public class MatchGroupMember {

    @EmbeddedId
    private MatchGroupMemberId id;

    @MapsId("groupId")
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "group_id", nullable = false)
    private MatchGroup group;

    @MapsId("userId")
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private MemberStatus status = MemberStatus.PENDING;

    @Column(name = "joined_at", nullable = false, updatable = false)
    private Instant joinedAt = Instant.now();

    public enum MemberStatus {
        PENDING, DISMISSED
    }
}
