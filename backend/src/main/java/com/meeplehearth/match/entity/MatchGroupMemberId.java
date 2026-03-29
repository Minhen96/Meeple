package com.meeplehearth.match.entity;

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
public class MatchGroupMemberId implements Serializable {

    @Column(name = "group_id")
    private UUID groupId;

    @Column(name = "user_id")
    private UUID userId;
}
