package com.meeplehearth.storage;

import java.util.UUID;
import java.util.regex.Pattern;

/**
 * Object key layout in R2. Every key a user uploads is {@code uploads/<userId>/<uuid>.<ext>}
 * (avatars use {@code avatars/<userId>/<uuid>.<ext>}), so ownership of a client-supplied key can
 * be checked from the key alone.
 */
public final class StorageKeys {

    public static final String UPLOADS_PREFIX = "uploads/";
    public static final String AVATARS_PREFIX = "avatars/";

    private static final Pattern UPLOAD_KEY = Pattern.compile(
            "^uploads/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/"
                    + "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\\.(jpg|png|webp|gif)$");

    private StorageKeys() {
    }

    /** {@code uploads/<userId>/} — the prefix every upload by this user starts with. */
    public static String userUploadPrefix(UUID userId) {
        return UPLOADS_PREFIX + userId + "/";
    }

    public static String newUploadKey(UUID userId, ImageType type) {
        return userUploadPrefix(userId) + UUID.randomUUID() + "." + type.extension();
    }

    public static String newAvatarKey(UUID userId, ImageType type) {
        return AVATARS_PREFIX + userId + "/" + UUID.randomUUID() + "." + type.extension();
    }

    /** True when {@code key} is a well-formed upload key that belongs to {@code userId}. */
    public static boolean isOwnedUploadKey(String key, UUID userId) {
        return key != null
                && UPLOAD_KEY.matcher(key).matches()
                && key.startsWith(userUploadPrefix(userId));
    }
}
