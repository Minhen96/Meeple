package com.meeplehearth.social.dto;

import com.meeplehearth.social.entity.FriendRequest;
import com.meeplehearth.user.dto.UserProfileResponse;

import java.time.Instant;
import java.util.UUID;

public record FriendRequestResponse(
        UUID id,
        UserProfileResponse sender,
        UserProfileResponse receiver,
        String status,
        Instant createdAt
) {
    public static FriendRequestResponse from(FriendRequest fr) {
        return new FriendRequestResponse(
                fr.getId(),
                UserProfileResponse.from(fr.getSender()),
                UserProfileResponse.from(fr.getReceiver()),
                fr.getStatus().name(),
                fr.getCreatedAt()
        );
    }
}
