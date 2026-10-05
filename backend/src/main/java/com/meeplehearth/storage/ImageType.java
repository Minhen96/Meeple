package com.meeplehearth.storage;

import java.util.Arrays;
import java.util.Optional;

/**
 * Image formats accepted for upload, identified by their file signature ("magic bytes")
 * rather than by the client-declared Content-Type.
 */
public enum ImageType {

    JPEG("image/jpeg", "jpg"),
    PNG("image/png", "png"),
    WEBP("image/webp", "webp"),
    GIF("image/gif", "gif");

    /** Number of leading bytes needed to recognise every supported format. */
    public static final int SIGNATURE_LENGTH = 12;

    private static final byte[] JPEG_MAGIC = {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF};
    private static final byte[] PNG_MAGIC = {(byte) 0x89, 'P', 'N', 'G', '\r', '\n', 0x1A, '\n'};
    private static final byte[] GIF87_MAGIC = {'G', 'I', 'F', '8', '7', 'a'};
    private static final byte[] GIF89_MAGIC = {'G', 'I', 'F', '8', '9', 'a'};
    private static final byte[] RIFF_MAGIC = {'R', 'I', 'F', 'F'};
    private static final byte[] WEBP_MAGIC = {'W', 'E', 'B', 'P'};

    private final String contentType;
    private final String extension;

    ImageType(String contentType, String extension) {
        this.contentType = contentType;
        this.extension = extension;
    }

    public String contentType() {
        return contentType;
    }

    public String extension() {
        return extension;
    }

    public static Optional<ImageType> fromContentType(String contentType) {
        return Arrays.stream(values()).filter(t -> t.contentType.equals(contentType)).findFirst();
    }

    /** Detects the image format from the file's leading bytes; empty when it is none of the allowed formats. */
    public static Optional<ImageType> detect(byte[] header) {
        if (header == null) {
            return Optional.empty();
        }
        if (startsWith(header, 0, JPEG_MAGIC)) {
            return Optional.of(JPEG);
        }
        if (startsWith(header, 0, PNG_MAGIC)) {
            return Optional.of(PNG);
        }
        if (startsWith(header, 0, GIF87_MAGIC) || startsWith(header, 0, GIF89_MAGIC)) {
            return Optional.of(GIF);
        }
        if (startsWith(header, 0, RIFF_MAGIC) && startsWith(header, 8, WEBP_MAGIC)) {
            return Optional.of(WEBP);
        }
        return Optional.empty();
    }

    private static boolean startsWith(byte[] data, int offset, byte[] magic) {
        if (data.length < offset + magic.length) {
            return false;
        }
        for (int i = 0; i < magic.length; i++) {
            if (data[offset + i] != magic[i]) {
                return false;
            }
        }
        return true;
    }
}
