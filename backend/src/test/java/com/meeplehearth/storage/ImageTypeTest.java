package com.meeplehearth.storage;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class ImageTypeTest {

    private static byte[] bytes(int... values) {
        byte[] out = new byte[values.length];
        for (int i = 0; i < values.length; i++) {
            out[i] = (byte) values[i];
        }
        return out;
    }

    @Test
    void detectsSupportedFormatsFromMagicBytes() {
        assertThat(ImageType.detect(bytes(0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10))).contains(ImageType.JPEG);
        assertThat(ImageType.detect(bytes(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0))).contains(ImageType.PNG);
        assertThat(ImageType.detect("GIF89a....".getBytes(StandardCharsets.US_ASCII))).contains(ImageType.GIF);
        assertThat(ImageType.detect("GIF87a....".getBytes(StandardCharsets.US_ASCII))).contains(ImageType.GIF);
        assertThat(ImageType.detect("RIFF\u0010\0\0\0WEBPVP8 ".getBytes(StandardCharsets.ISO_8859_1)))
                .contains(ImageType.WEBP);
    }

    @Test
    void rejectsNonImageContentRegardlessOfDeclaredType() {
        assertThat(ImageType.detect("<svg xmlns=\"http://www.w3.org/2000/svg\">".getBytes(StandardCharsets.UTF_8)))
                .isEmpty();
        assertThat(ImageType.detect("<html><script>alert(1)</script>".getBytes(StandardCharsets.UTF_8))).isEmpty();
        assertThat(ImageType.detect("RIFF\u0010\0\0\0WAVEfmt ".getBytes(StandardCharsets.ISO_8859_1))).isEmpty();
        assertThat(ImageType.detect(bytes(0xFF, 0xD8))).isEmpty();
        assertThat(ImageType.detect(new byte[0])).isEmpty();
        assertThat(ImageType.detect(null)).isEmpty();
    }

    @Test
    void uploadKeysAreScopedToTheirOwner() {
        UUID owner = UUID.randomUUID();
        String key = StorageKeys.newUploadKey(owner, ImageType.PNG);

        assertThat(key).startsWith("uploads/" + owner + "/").endsWith(".png");
        assertThat(StorageKeys.isOwnedUploadKey(key, owner)).isTrue();
        assertThat(StorageKeys.isOwnedUploadKey(key, UUID.randomUUID())).isFalse();
        assertThat(StorageKeys.isOwnedUploadKey("uploads/" + owner + "/../other.png", owner)).isFalse();
        assertThat(StorageKeys.isOwnedUploadKey("avatars/" + owner + "/" + UUID.randomUUID() + ".png", owner))
                .isFalse();
    }
}
