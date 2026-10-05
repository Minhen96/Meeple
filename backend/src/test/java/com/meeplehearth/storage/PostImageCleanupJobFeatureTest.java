package com.meeplehearth.storage;

import com.meeplehearth.config.AppProperties;
import com.meeplehearth.storage.job.PostImageCleanupJob;
import com.meeplehearth.user.AccountFeatureTestBase;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import software.amazon.awssdk.services.s3.model.DeleteObjectsRequest;

import java.time.Duration;
import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** post_image_cleanup: R2 objects of posts deleted over 30 days ago are removed, live posts untouched. */
class PostImageCleanupJobFeatureTest extends AccountFeatureTestBase {

    @Autowired PostImageCleanupJob job;
    @Autowired AppProperties appProperties;

    private UUID post(UUID author, Instant deletedAt) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO posts (id, author_id, deleted_at) VALUES (?, ?, ?)",
                id, author, deletedAt == null ? null : ts(deletedAt));
        return id;
    }

    private UUID image(UUID postId, String url) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO post_images (id, post_id, url) VALUES (?, ?, ?)", id, postId, url);
        return id;
    }

    @Test
    void deletesImagesOfLongDeletedPostsOnly() {
        UUID author = user();
        String base = appProperties.getR2().getPublicUrl();
        UUID oldPost = post(author, Instant.now().minus(Duration.ofDays(40)));
        UUID recentPost = post(author, Instant.now().minus(Duration.ofDays(5)));
        UUID livePost = post(author, null);
        String oldKey = "uploads/" + author + "/" + UUID.randomUUID() + ".webp";
        UUID oldImage = image(oldPost, base + "/" + oldKey);
        UUID foreignImage = image(oldPost, "https://elsewhere.example/x.jpg");
        UUID recentImage = image(recentPost, base + "/uploads/" + author + "/" + UUID.randomUUID() + ".webp");
        UUID liveImage = image(livePost, base + "/uploads/" + author + "/" + UUID.randomUUID() + ".webp");

        assertThat(job.cleanUp()).isGreaterThanOrEqualTo(2);

        verify(s3Client).deleteObjects(argThat((DeleteObjectsRequest r) ->
                r.delete().objects().stream().anyMatch(o -> o.key().equals(oldKey))
                        && r.delete().objects().stream().noneMatch(o -> o.key().contains("elsewhere"))));
        assertThat(count("SELECT count(*) FROM post_images WHERE id IN (?, ?)", oldImage, foreignImage)).isZero();
        assertThat(count("SELECT count(*) FROM post_images WHERE id IN (?, ?)", recentImage, liveImage)).isEqualTo(2);
    }

    @Test
    void keepsRowsWhenStorageFails() {
        UUID author = user();
        UUID oldPost = post(author, Instant.now().minus(Duration.ofDays(45)));
        UUID img = image(oldPost, appProperties.getR2().getPublicUrl() + "/uploads/" + author + "/" + UUID.randomUUID() + ".png");
        when(s3Client.deleteObjects(any(DeleteObjectsRequest.class))).thenThrow(new IllegalStateException("R2 down"));

        job.run();

        assertThat(count("SELECT count(*) FROM post_images WHERE id = ?", img)).isEqualTo(1);
    }
}
