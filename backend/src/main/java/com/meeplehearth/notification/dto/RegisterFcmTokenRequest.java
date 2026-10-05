package com.meeplehearth.notification.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** {@code POST /api/v1/users/me/fcm-tokens {token, platform: "web"|"ios"|"android", deviceInfo?}}. */
public record RegisterFcmTokenRequest(
        @NotBlank @Size(max = 255) String token,
        @NotBlank @Pattern(regexp = "^(web|ios|android)$", message = "platform must be web, ios or android")
        String platform,
        @Size(max = 255) String deviceInfo
) {
}
