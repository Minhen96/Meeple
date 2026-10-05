package com.meeplehearth.storage.service;

import com.meeplehearth.config.AppProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
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
 * Server-side object operations on the R2 bucket used by account and cleanup jobs: private
 * uploads (data exports), time-limited download links, and deletion by key or prefix.
 */
@Service
public class ObjectStorageService {

    private static final Logger log = LoggerFactory.getLogger(ObjectStorageService.class);
    /** S3 DeleteObjects accepts at most 1000 keys per call. */
    static final int DELETE_BATCH = 1000;
    /** SigV4 presigned URLs are valid for at most 7 days. */
    public static final Duration MAX_PRESIGN = Duration.ofDays(7);

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

    public void put(String key, byte[] content, String contentType) {
        s3Client.putObject(PutObjectRequest.builder()
                        .bucket(bucket())
                        .key(key)
                        .contentType(contentType)
                        .contentLength((long) content.length)
                        .build(),
                RequestBody.fromBytes(content));
    }

    /** A GET link for a private object, valid for {@code validFor} (capped at 7 days). */
    public String presignGet(String key, Duration validFor) {
        Duration duration = validFor.compareTo(MAX_PRESIGN) > 0 ? MAX_PRESIGN : validFor;
        GetObjectPresignRequest request = GetObjectPresignRequest.builder()
                .signatureDuration(duration)
                .getObjectRequest(GetObjectRequest.builder().bucket(bucket()).key(key).build())
                .build();
        return s3Presigner.presignGetObject(request).url().toString();
    }

    /** Deletes the given keys in batches; returns the number of keys sent for deletion. */
    public int deleteKeys(List<String> keys) {
        int deleted = 0;
        for (int start = 0; start < keys.size(); start += DELETE_BATCH) {
            List<ObjectIdentifier> batch = keys.subList(start, Math.min(keys.size(), start + DELETE_BATCH)).stream()
                    .map(key -> ObjectIdentifier.builder().key(key).build())
                    .toList();
            s3Client.deleteObjects(DeleteObjectsRequest.builder()
                    .bucket(bucket())
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
        if (prefix == null || prefix.isBlank() || !prefix.endsWith("/")) {
            throw new IllegalArgumentException("Prefix must be a non-empty folder path ending in '/'");
        }
        List<String> keys = new ArrayList<>();
        String continuation = null;
        do {
            ListObjectsV2Response page = s3Client.listObjectsV2(ListObjectsV2Request.builder()
                    .bucket(bucket())
                    .prefix(prefix)
                    .continuationToken(continuation)
                    .build());
            page.contents().stream().map(S3Object::key).forEach(keys::add);
            continuation = Boolean.TRUE.equals(page.isTruncated()) ? page.nextContinuationToken() : null;
        } while (continuation != null);
        return keys.isEmpty() ? 0 : deleteKeys(keys);
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
