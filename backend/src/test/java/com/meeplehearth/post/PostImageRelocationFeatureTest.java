package com.meeplehearth.post;

import com.meeplehearth.config.AppProperties;
import com.meeplehearth.post.service.PostImageRelocator;
import com.meeplehearth.user.AccountFeatureTestBase;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import software.amazon.awssdk.services.s3.model.CopyObjectRequest;
import software.amazon.awssdk.services.s3.model.DeleteObjectsRequest;
import software.amazon.awssdk.services.s3.model.S3Exception;

import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.awaitility.Awaitility.await;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.Mockito.atLeast;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Post image key move (FEATURES_COMPLETE section 5.2): after a post is created its images are
 * copied from {@code uploads/{userId}/} to {@code posts/{postId}/}, the rows point at the new
 * keys and the originals are deleted. Failures leave the original (still valid) key in place.
 */
class PostImageRelocationFeatureTest extends AccountFeatureTestBase {

    @Autowired PostImageRelocator relocator;
    @Autowired AppProperties appProperties;

    private String base() {
        return appProperties.getR2().getPublicUrl();
    }

    private static String uploadKey(UUID userId) {
        return "uploads/" + userId + "/" + UUID.randomUUID() + ".webp";
    }

    private UUID newPost(UUID author) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO posts (id, author_id) VALUES (?, ?)", id, author);
        return id;
    }

    private UUID image(UUID postId, String url, int order) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO post_images (id, post_id, url, display_order) VALUES (?, ?, ?, ?)", id, postId, url, order);
        return id;
    }

    private String url(UUID imageId) {
        return string("SELECT url FROM post_images WHERE id = ?", imageId);
    }

    private static DeleteObjectsRequest deletes(String key) {
        return argThat((DeleteObjectsRequest r) -> r != null
                && r.delete().objects().stream().anyMatch(o -> o.key().equals(key)));
    }

    @Test
    void movesUploadsUnderThePostAndDeletesTheOriginals() {
        UUID author = user();
        UUID postId = newPost(author);
        String first = uploadKey(author);
        String second = uploadKey(author).replace(".webp", ".jpg");
        UUID img0 = image(postId, base() + "/" + first, 0);
        UUID img1 = image(postId, base() + "/" + second, 1);
        UUID foreign = image(postId, "https://elsewhere.example/x.png", 2);

        assertThat(relocator.relocate(postId)).isEqualTo(2);

        assertThat(url(img0)).isEqualTo(base() + "/posts/" + postId + "/0.webp");
        assertThat(url(img1)).isEqualTo(base() + "/posts/" + postId + "/1.jpg");
        assertThat(url(foreign)).isEqualTo("https://elsewhere.example/x.png");
        verify(s3Client).copyObject(argThat((CopyObjectRequest r) ->
                r.sourceKey().equals(first) && r.destinationKey().equals("posts/" + postId + "/0.webp")
                        && r.sourceBucket().equals(r.destinationBucket())));
        verify(s3Client).deleteObjects(deletes(first));
        verify(s3Client).deleteObjects(deletes(second));
        // Already moved: a second run does nothing
        assertThat(relocator.relocate(postId)).isZero();
    }

    @Test
    void copyFailureKeepsTheOriginalKey() {
        UUID author = user();
        UUID postId = newPost(author);
        String key = uploadKey(author);
        UUID img = image(postId, base() + "/" + key, 0);
        when(s3Client.copyObject(any(CopyObjectRequest.class)))
                .thenThrow(S3Exception.builder().message("R2 down").statusCode(503).build());

        assertThat(relocator.relocate(postId)).isZero();

        assertThat(url(img)).isEqualTo(base() + "/" + key);
        verify(s3Client, atLeast(2)).copyObject(any(CopyObjectRequest.class)); // retried
        verify(s3Client, never()).deleteObjects(any(DeleteObjectsRequest.class));
    }

    @Test
    void anOriginalStillUsedByAnotherPostIsNotDeleted() {
        UUID author = user();
        String key = uploadKey(author);
        UUID firstPost = newPost(author);
        UUID secondPost = newPost(author);
        image(firstPost, base() + "/" + key, 0);
        UUID other = image(secondPost, base() + "/" + key, 0);

        assertThat(relocator.relocate(firstPost)).isEqualTo(1);

        verify(s3Client, never()).deleteObjects(deletes(key));
        assertThat(url(other)).isEqualTo(base() + "/" + key);

        assertThat(relocator.relocate(secondPost)).isEqualTo(1);
        verify(s3Client).deleteObjects(deletes(key));
    }

    @Test
    void aRowRemovedDuringTheCopyDropsTheCopy() {
        UUID author = user();
        UUID postId = newPost(author);
        String key = uploadKey(author);
        UUID img = image(postId, base() + "/" + key, 0);
        when(s3Client.copyObject(any(CopyObjectRequest.class))).thenAnswer(inv -> {
            jdbc.update("DELETE FROM post_images WHERE id = ?", img);
            return null;
        });

        assertThat(relocator.relocate(postId)).isZero();

        verify(s3Client).deleteObjects(deletes("posts/" + postId + "/0.webp"));
        verify(s3Client, never()).deleteObjects(deletes(key));
    }

    @Test
    void creatingAPostMovesItsImagesAfterCommit() throws Exception {
        UUID author = user();
        String key = uploadKey(author);

        String created = mvc.perform(post("/api/v1/posts").with(as(author))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(Map.of("caption", "game night", "imageKeys", List.of(key)))))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        UUID postId = UUID.fromString(objectMapper.readTree(created).get("data").get("id").asText());

        await().atMost(Duration.ofSeconds(10)).untilAsserted(() ->
                assertThat(string("SELECT url FROM post_images WHERE post_id = ?", postId))
                        .isEqualTo(base() + "/posts/" + postId + "/0.webp"));
        await().atMost(Duration.ofSeconds(10)).untilAsserted(() -> verify(s3Client).deleteObjects(deletes(key)));
    }
}
