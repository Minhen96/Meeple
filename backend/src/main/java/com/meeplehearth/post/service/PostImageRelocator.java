package com.meeplehearth.post.service;

import com.meeplehearth.storage.StorageKeys;
import com.meeplehearth.storage.service.ObjectStorageService;
import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;
import io.github.resilience4j.retry.Retry;
import io.github.resilience4j.retry.RetryRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * Moves a new post's images from the uploader's staging folder to the post's own folder
 * (FEATURES_COMPLETE section 5.2, step 6): {@code uploads/{userId}/{uuid}.{ext}} is copied to
 * {@code posts/{postId}/{displayOrder}.{ext}}, {@code post_images.url} is switched to the new key
 * and the upload original is deleted.
 *
 * <p>Runs asynchronously after the post's transaction commits; R2 calls go through the
 * {@code r2} circuit breaker and retry. Any failure leaves the image on its original key, which
 * stays valid (the post keeps working); only that image is skipped. An original still referenced
 * by another {@code post_images} row is never deleted.
 */
@Component
public class PostImageRelocator {

    private static final Logger log = LoggerFactory.getLogger(PostImageRelocator.class);
    static final String RESILIENCE_NAME = "r2";
    static final String POSTS_PREFIX = "posts/";

    /** Published by {@link PostService#createPost} when the new post has images. */
    public record PostImagesAdded(UUID postId) {}

    private final JdbcTemplate jdbc;
    private final ObjectStorageService storage;
    private final CircuitBreaker circuitBreaker;
    private final Retry retry;

    public PostImageRelocator(JdbcTemplate jdbc,
                              ObjectStorageService storage,
                              CircuitBreakerRegistry circuitBreakers,
                              RetryRegistry retries) {
        this.jdbc = jdbc;
        this.storage = storage;
        this.circuitBreaker = circuitBreakers.circuitBreaker(RESILIENCE_NAME);
        this.retry = retries.retry(RESILIENCE_NAME);
    }

    @Async
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onPostImagesAdded(PostImagesAdded event) {
        relocate(event.postId());
    }

    /** Moves every staged image of {@code postId}; returns how many were moved. */
    public int relocate(UUID postId) {
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT id, url, display_order FROM post_images WHERE post_id = ? ORDER BY display_order",
                postId);
        int moved = 0;
        for (Map<String, Object> row : rows) {
            UUID imageId = (UUID) row.get("id");
            String url = (String) row.get("url");
            int order = ((Number) row.get("display_order")).intValue();
            Optional<String> source = storage.keyFromPublicUrl(url).filter(k -> k.startsWith(StorageKeys.UPLOADS_PREFIX));
            if (source.isPresent() && move(postId, imageId, url, source.get(), order)) {
                moved++;
            }
        }
        return moved;
    }

    private boolean move(UUID postId, UUID imageId, String oldUrl, String sourceKey, int order) {
        String destinationKey = destinationKey(postId, sourceKey, order);
        try {
            resilient(() -> storage.copy(sourceKey, destinationKey));
        } catch (RuntimeException e) {
            log.warn("Could not move image {} of post {}; it stays on its upload key: {}",
                    imageId, postId, e.getClass().getSimpleName());
            return false;
        }
        // Compare-and-set: the row may have been removed (post hard-deleted) meanwhile
        int updated = jdbc.update("UPDATE post_images SET url = ? WHERE id = ? AND url = ?",
                storage.publicUrl(destinationKey), imageId, oldUrl);
        if (updated == 0) {
            deleteQuietly(destinationKey);
            return false;
        }
        Integer stillUsed = jdbc.queryForObject("SELECT COUNT(*) FROM post_images WHERE url = ?", Integer.class, oldUrl);
        if (stillUsed == null || stillUsed == 0) {
            deleteQuietly(sourceKey);
        }
        return true;
    }

    private void deleteQuietly(String key) {
        try {
            resilient(() -> storage.deleteKeys(List.of(key)));
        } catch (RuntimeException e) {
            log.warn("Could not delete object after image move: {}", e.getClass().getSimpleName());
        }
    }

    private void resilient(Runnable call) {
        Retry.decorateRunnable(retry, CircuitBreaker.decorateRunnable(circuitBreaker, call)).run();
    }

    /** {@code posts/{postId}/{order}.{ext}}, keeping the upload's extension. */
    static String destinationKey(UUID postId, String sourceKey, int order) {
        int dot = sourceKey.lastIndexOf('.');
        int slash = sourceKey.lastIndexOf('/');
        String ext = dot > slash ? sourceKey.substring(dot) : "";
        return POSTS_PREFIX + postId + "/" + order + ext;
    }
}
