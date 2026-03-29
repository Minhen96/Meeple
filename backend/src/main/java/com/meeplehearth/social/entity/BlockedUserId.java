package com.meeplehearth.social.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import lombok.AllArgsConstructor;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.io.Serializable;
import java.util.UUID;

@Embeddable
@Getter
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode
public class BlockedUserId implements Serializable {

    @Column(name = "blocker_id")
    private UUID blockerId;

    @Column(name = "blocked_id")
    private UUID blockedId;
}
