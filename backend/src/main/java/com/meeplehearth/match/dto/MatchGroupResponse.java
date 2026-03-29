package com.meeplehearth.match.dto;

import com.meeplehearth.game.dto.GameSummaryResponse;
import com.meeplehearth.match.entity.MatchGroup;
import com.meeplehearth.user.dto.UserProfileResponse;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record MatchGroupResponse(
        UUID id,
        GameSummaryResponse game,
        Instant overlapStart,
        Instant overlapEnd,
        String status,
        List<UserProfileResponse> members,
        Instant createdAt
) {
    public static MatchGroupResponse from(MatchGroup mg) {
        List<UserProfileResponse> members = mg.getMembers().stream()
                .map(m -> UserProfileResponse.from(m.getUser()))
                .toList();
        return new MatchGroupResponse(
                mg.getId(),
                GameSummaryResponse.from(mg.getGame()),
                mg.getOverlapStart(),
                mg.getOverlapEnd(),
                mg.getStatus().name(),
                members,
                mg.getCreatedAt()
        );
    }
}
