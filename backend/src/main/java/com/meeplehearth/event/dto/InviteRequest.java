package com.meeplehearth.event.dto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;
import java.util.UUID;

/** {@code POST /api/v1/events/{id}/invites}: friends of the host to invite. */
public record InviteRequest(
        @NotEmpty @Size(max = 50) List<@NotNull UUID> userIds
) {
}
