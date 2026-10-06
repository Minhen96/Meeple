package com.meeplehearth.storage.service;

import com.meeplehearth.config.AppProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.CopyObjectRequest;
import software.amazon.awssdk.services.s3.model.Delete;
import software.amazon.awssdk.services.s3.model.DeleteObjectsRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.ListObjectsV2Request;
import software.amazon.awssdk.services.s3.model.ListObjectsV2Response;
import software.amazon.awssdk.services.s3.model.ObjectIdentifier;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.S3Object;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;

import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * Server-side object operations on R2 used by account and cleanup jobs: deletion by key or
 * prefix in the public media bucket, and private objects (data exports) with time-limited
 * download links.
 *
 * <p>Private objects live in {@code app.r2.private-bucket} ({@code R2_PRIVATE_BUCKET}), a bucket
 * that has no public domain. When it is not configured they fall back to the media bucket under
 * {@link #PRIVATE_FALLBACK_PREFIX}, and a WARN at startup says that path must be blocked on the
 * public domain. Callers always pass logical keys (e.g. {@code exports/<user>/<id>.zip}); the
 * {@code *Private*} methods map them to the physical bucket and key. A public URL is never built
 * for a private key.
 */
@Service
public class ObjectStorageService {

    private static final Logger log = LoggerFactory.getLogger(ObjectStorageService.class);
    /** S3 DeleteObjects accepts at most 1000 keys per call. */
    static final int DELETE_BATCH = 1000;
    /** SigV4 presigned URLs are valid for at most 7 days. */
    public static final Duration MAX_PRESIGN = Duration.ofDays(7);
    /** Key prefix of private objects when they share the media bucket (no private bucket set). */
    public static final String PRIVATE_FALLBACK_PREFIX = "private/";
    /** Logical prefixes that are always private; {@link #publicUrl} refuses them. */
    private static final List<String> PRIVATE_KEY_PREFIXES = List.of(PRIVATE_FALLBACK_PREFIX, "exports/");

    private final S3Client s3Client;
    private final S3Presigner s3Presigner;
    private final AppProperties appProperties;

    public ObjectStorageService(S3Client s3Client, S3Presigner s3Presigner, AppProperties appProperties) {
        this.s3Client = s3Client;
        this.s3Presigner = s3Presigner;
        this.appProperties = appProperties;
    }

    private String bucket() {
        return appProperties.getR2().getBucket();
    }

    /** Whether a dedicated private bucket is configured (otherwise private objects share the media bucket). */
    public boolean hasPrivateBucket() {
        String privateBucket = appProperties.getR2().getPrivateBucket();
        return privateBucket != null && !privateBucket.isBlank();
    }

    private String privateBucket() {
        return hasPrivateBucket() ? appProperties.getR2().getPrivateBucket().trim() : bucket();
    }

    /** Physical key of a private object: unchanged in the private bucket, prefixed in the fallback. */
    String privateKey(String key) {
        return hasPrivateBucket() ? key : PRIVATE_FALLBACK_PREFIX + key;
    }

    /** Startup check: without a private bucket, exports sit in the public media bucket. */
    @EventListener(ApplicationReadyEvent.class)
    public void warnIfPrivateBucketMissing() {
        if (!hasPrivateBucket()) {
            log.warn("R2_PRIVATE_BUCKET is not set: data exports are stored in the media bucket under '{}'."
                    + " Block that path on the public media domain (e.g. a Cloudflare rule) or set a private"
                    + " bucket.", PRIVATE_FALLBACK_PREFIX);
        }
    }

    /** Stores a private object (logical key); it is reachable only through {@link #presignPrivateGet}. */
    public void putPrivate(String key, byte[] content, String contentType) {
        put(privateBucket(), privateKey(key), content, contentType);
    }

    private void put(String bucket, String key, byte[] content, String contentType) {
        s3Client.putObject(PutObjectRequest.builder()
                        .bucket(bucket)
                        .key(key)
                        .contentType(contentType)
                        .contentLength((long) content.length)
                        .build(),
                RequestBody.fromBytes(content));
    }

    /** Server-side copy of one object to another key in the same bucket (S3 CopyObject). */
    public void copy(String sourceKey, String destinationKey) {
        s3Client.copyObject(CopyObjectRequest.builder()
                .sourceBucket(bucket())
                .sourceKey(sourceKey)
                .destinationBucket(bucket())
                .destinationKey(destinationKey)
                .build());
    }

    /** Same as {@link #deleteKeys} but logs and swallows storage failures (best-effort cleanup). */
    public int deleteKeysQuietly(List<String> keys) {
        if (keys.isEmpty()) {
            return 0;
        }
        try {
            return deleteKeys(keys);
        } catch (RuntimeException e) {
            log.warn("Could not delete {} objects: {}", keys.size(), e.getClass().getSimpleName());
            return 0;
        }
    }

    /**
     * The public CDN URL of an object key in this bucket ({@code {publicUrl}/{key}}). Refuses
     * private keys (exports, the private fallback prefix).
     */
    public String publicUrl(String key) {
        if (key == null || PRIVATE_KEY_PREFIXES.stream().anyMatch(key::startsWith)) {
            throw new IllegalArgumentException("Private objects have no public URL");
        }
        String base = appProperties.getR2().getPublicUrl();
        return (base.endsWith("/") ? base : base + "/") + key;
    }

    /** A GET link for a private object (logical key), valid for {@code validFor} (capped at 7 days). */
    public String presignPrivateGet(String key, Duration validFor) {
        Duration duration = validFor.compareTo(MAX_PRESIGN) > 0 ? MAX_PRESIGN : validFor;
        GetObjectPresignRequest request = GetObjectPresignRequest.builder()
                .signatureDuration(duration)
                .getObjectRequest(GetObjectRequest.builder().bucket(privateBucket()).key(privateKey(key)).build())
                .build();
        return s3Presigner.presignGetObject(request).url().toString();
    }

    /** Deletes private objects by logical key; returns the number of keys sent for deletion. */
    public int deletePrivateKeys(List<String> keys) {
        return deleteKeys(privateBucket(), keys.stream().map(this::privateKey).toList());
    }

    /** Deletes every private object under a logical folder prefix; logs and swallows storage failures. */
    public int deletePrivatePrefixQuietly(String prefix) {
        try {
            requireFolder(prefix);
            return deletePrefix(privateBucket(), privateKey(prefix));
        } catch (RuntimeException e) {
            log.warn("Could not delete private objects under {}: {}", prefix, e.getClass().getSimpleName());
            return 0;
        }
    }

    /** Deletes the given keys in batches; returns the number of keys sent for deletion. */
    public int deleteKeys(List<String> keys) {
        return deleteKeys(bucket(), keys);
    }

    private int deleteKeys(String bucket, List<String> keys) {
        int deleted = 0;
        for (int start = 0; start < keys.size(); start += DELETE_BATCH) {
            List<ObjectIdentifier> batch = keys.subList(start, Math.min(keys.size(), start + DELETE_BATCH)).stream()
                    .map(key -> ObjectIdentifier.builder().key(key).build())
                    .toList();
            s3Client.deleteObjects(DeleteObjectsRequest.builder()
                    .bucket(bucket)
                    .delete(Delete.builder().objects(batch).quiet(true).build())
                    .build());
            deleted += batch.size();
        }
        return deleted;
    }

    /**
     * Deletes every object whose key starts with {@code prefix}. The prefix must end with "/" so
     * that, for example, {@code avatars/<id>/} can never match another user's folder.
     */
    public int deletePrefix(String prefix) {
        requireFolder(prefix);
        return deletePrefix(bucket(), prefix);
    }

    private static void requireFolder(String prefix) {
        if (prefix == null || prefix.isBlank() || !prefix.endsWith("/")) {
            throw new IllegalArgumentException("Prefix must be a non-empty folder path ending in '/'");
        }
    }

    private int deletePrefix(String bucket, String prefix) {
        List<String> keys = new ArrayList<>();
        String continuation = null;
        do {
            ListObjectsV2Response page = s3Client.listObjectsV2(ListObjectsV2Request.builder()
                    .bucket(bucket)
                    .prefix(prefix)
                    .continuationToken(continuation)
                    .build());
            page.contents().stream().map(S3Object::key).forEach(keys::add);
            continuation = Boolean.TRUE.equals(page.isTruncated()) ? page.nextContinuationToken() : null;
        } while (continuation != null);
        return keys.isEmpty() ? 0 : deleteKeys(bucket, keys);
    }

    /** Same as {@link #deletePrefix} but logs and swallows storage failures (best-effort cleanup). */
    public int deletePrefixQuietly(String prefix) {
        try {
            return deletePrefix(prefix);
        } catch (RuntimeException e) {
            log.warn("Could not delete objects under {}: {}", prefix, e.getClass().getSimpleName());
            return 0;
        }
    }

    /**
     * The object key behind a public CDN URL of this bucket ({@code {publicUrl}/{key}}), or empty if
     * the URL points elsewhere (for example a Google avatar).
     */
    public Optional<String> keyFromPublicUrl(String url) {
        String base = appProperties.getR2().getPublicUrl();
        if (url == null || base == null || base.isBlank()) {
            return Optional.empty();
        }
        String prefix = base.endsWith("/") ? base : base + "/";
        if (!url.startsWith(prefix) || url.length() == prefix.length()) {
            return Optional.empty();
        }
        String key = url.substring(prefix.length());
        if (key.contains("..") || key.startsWith("/")) {
            return Optional.empty();
        }
        return Optional.of(key);
    }
}
