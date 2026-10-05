package com.meeplehearth.storage;

import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class StorageKeysTest {

    private final UUID owner = UUID.randomUUID();

    @Test
    void newKeysFollowTheDocumentedLayout() {
        assertThat(StorageKeys.userUploadPrefix(owner)).isEqualTo("uploads/" + owner + "/");
        assertThat(StorageKeys.newUploadKey(owner, ImageType.GIF))
                .matches("uploads/" + owner + "/[0-9a-f-]{36}\\.gif");
        assertThat(StorageKeys.newAvatarKey(owner, ImageType.WEBP))
                .matches("avatars/" + owner + "/[0-9a-f-]{36}\\.webp");
        assertThat(StorageKeys.newUploadKey(owner, ImageType.PNG)).isNotEqualTo(StorageKeys.newUploadKey(owner, ImageType.PNG));
    }

    @Test
    void ownershipRequiresAWellFormedKeyUnderTheOwnersPrefix() {
        String key = StorageKeys.newUploadKey(owner, ImageType.JPEG);

        assertThat(StorageKeys.isOwnedUploadKey(key, owner)).isTrue();
        assertThat(StorageKeys.isOwnedUploadKey(null, owner)).isFalse();
        assertThat(StorageKeys.isOwnedUploadKey(key, UUID.randomUUID())).isFalse();
        // Avatars, traversal, other extensions and upper-case ids are not upload keys
        assertThat(StorageKeys.isOwnedUploadKey(StorageKeys.newAvatarKey(owner, ImageType.JPEG), owner)).isFalse();
        assertThat(StorageKeys.isOwnedUploadKey("uploads/" + owner + "/../" + UUID.randomUUID() + ".jpg", owner)).isFalse();
        assertThat(StorageKeys.isOwnedUploadKey(key.replace(".jpg", ".svg"), owner)).isFalse();
        assertThat(StorageKeys.isOwnedUploadKey(key.toUpperCase(), owner)).isFalse();
    }

    @Test
    void contentTypeLookupIsExact() {
        assertThat(ImageType.fromContentType("image/png")).contains(ImageType.PNG);
        assertThat(ImageType.fromContentType("IMAGE/PNG")).isEmpty();
        assertThat(ImageType.fromContentType(null)).isEmpty();
        assertThat(ImageType.WEBP.contentType()).isEqualTo("image/webp");
        assertThat(ImageType.JPEG.extension()).isEqualTo("jpg");
    }
}
