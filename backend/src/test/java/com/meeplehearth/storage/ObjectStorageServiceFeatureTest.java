package com.meeplehearth.storage;

import com.meeplehearth.config.AppProperties;
import com.meeplehearth.storage.service.ObjectStorageService;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.DeleteObjectsRequest;
import software.amazon.awssdk.services.s3.model.ListObjectsV2Request;
import software.amazon.awssdk.services.s3.model.ListObjectsV2Response;
import software.amazon.awssdk.services.s3.model.S3Object;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;

import java.net.URI;
import java.time.Duration;
import java.util.List;
import java.util.stream.IntStream;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class ObjectStorageServiceFeatureTest {

    private final S3Client s3 = mock(S3Client.class);
    private final AppProperties props = new AppProperties();
    private final S3Presigner presigner = S3Presigner.builder()
            .endpointOverride(URI.create("https://r2.example"))
            .region(Region.of("auto"))
            .credentialsProvider(StaticCredentialsProvider.create(AwsBasicCredentials.create("k", "s")))
            .build();
    private final ObjectStorageService storage;

    ObjectStorageServiceFeatureTest() {
        props.getR2().setBucket("bucket");
        props.getR2().setPublicUrl("https://cdn.example/media");
        storage = new ObjectStorageService(s3, presigner, props);
    }

    @Test
    void deletesAPrefixAcrossPagesInBatches() {
        List<S3Object> firstPage = IntStream.range(0, 1000)
                .mapToObj(i -> S3Object.builder().key("avatars/u/" + i).build()).toList();
        when(s3.listObjectsV2(any(ListObjectsV2Request.class)))
                .thenReturn(ListObjectsV2Response.builder().contents(firstPage).isTruncated(true)
                        .nextContinuationToken("next").build())
                .thenReturn(ListObjectsV2Response.builder()
                        .contents(S3Object.builder().key("avatars/u/last").build()).isTruncated(false).build());

        assertThat(storage.deletePrefix("avatars/u/")).isEqualTo(1001);
        verify(s3, times(2)).deleteObjects(any(DeleteObjectsRequest.class));
        verify(s3, times(2)).listObjectsV2(any(ListObjectsV2Request.class));
    }

    @Test
    void refusesPrefixesThatCouldMatchOtherFolders() {
        assertThatThrownBy(() -> storage.deletePrefix("avatars/u")).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> storage.deletePrefix("")).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> storage.deletePrefix(null)).isInstanceOf(IllegalArgumentException.class);
        when(s3.listObjectsV2(any(ListObjectsV2Request.class))).thenThrow(new IllegalStateException("down"));
        assertThat(storage.deletePrefixQuietly("uploads/u/")).isZero();
        assertThat(storage.deletePrefixQuietly("bad")).isZero();
    }

    @Test
    void emptyPrefixDeletesNothing() {
        when(s3.listObjectsV2(any(ListObjectsV2Request.class)))
                .thenReturn(ListObjectsV2Response.builder().isTruncated(false).build());
        assertThat(storage.deletePrefix("exports/u/")).isZero();
        verify(s3, times(0)).deleteObjects(any(DeleteObjectsRequest.class));
    }

    @Test
    void mapsPublicUrlsToKeys() {
        assertThat(storage.keyFromPublicUrl("https://cdn.example/media/uploads/u/x.webp")).contains("uploads/u/x.webp");
        assertThat(storage.keyFromPublicUrl("https://lh3.googleusercontent.com/a.png")).isEmpty();
        assertThat(storage.keyFromPublicUrl("https://cdn.example/media/")).isEmpty();
        assertThat(storage.keyFromPublicUrl("https://cdn.example/media/../secret")).isEmpty();
        assertThat(storage.keyFromPublicUrl(null)).isEmpty();
        props.getR2().setPublicUrl("");
        assertThat(storage.keyFromPublicUrl("https://cdn.example/media/a")).isEmpty();
    }

    @Test
    void presignsDownloadsForAtMostSevenDays() {
        String url = storage.presignPrivateGet("exports/u/e.zip", Duration.ofDays(30));
        assertThat(url).startsWith("https://").contains("exports/u/e.zip").contains("X-Amz-Expires=604800");
    }

    @Test
    void privateObjectsFallBackToAPrefixInTheMediaBucketWithoutAPrivateBucket() {
        assertThat(storage.hasPrivateBucket()).isFalse();
        storage.warnIfPrivateBucketMissing();

        storage.putPrivate("exports/u/e.zip", new byte[]{1, 2}, "application/zip");
        ArgumentCaptor<PutObjectRequest> put = ArgumentCaptor.forClass(PutObjectRequest.class);
        verify(s3).putObject(put.capture(), any(RequestBody.class));
        assertThat(put.getValue().bucket()).isEqualTo("bucket");
        assertThat(put.getValue().key()).isEqualTo("private/exports/u/e.zip");
        assertThat(storage.presignPrivateGet("exports/u/e.zip", Duration.ofDays(1)))
                .contains("bucket").contains("/private/exports/u/e.zip").doesNotContain("cdn.example");

        storage.deletePrivateKeys(List.of("exports/u/e.zip"));
        ArgumentCaptor<DeleteObjectsRequest> delete = ArgumentCaptor.forClass(DeleteObjectsRequest.class);
        verify(s3).deleteObjects(delete.capture());
        assertThat(delete.getValue().bucket()).isEqualTo("bucket");
        assertThat(delete.getValue().delete().objects().get(0).key()).isEqualTo("private/exports/u/e.zip");
    }

    @Test
    void privateObjectsGoToThePrivateBucketWhenConfigured() {
        props.getR2().setPrivateBucket(" exports-private ");
        assertThat(storage.hasPrivateBucket()).isTrue();
        storage.warnIfPrivateBucketMissing();

        storage.putPrivate("exports/u/e.zip", new byte[]{1}, "application/zip");
        ArgumentCaptor<PutObjectRequest> put = ArgumentCaptor.forClass(PutObjectRequest.class);
        verify(s3).putObject(put.capture(), any(RequestBody.class));
        assertThat(put.getValue().bucket()).isEqualTo("exports-private");
        assertThat(put.getValue().key()).isEqualTo("exports/u/e.zip");
        assertThat(storage.presignPrivateGet("exports/u/e.zip", Duration.ofDays(1)))
                .contains("exports-private").contains("/exports/u/e.zip");

        when(s3.listObjectsV2(any(ListObjectsV2Request.class))).thenReturn(ListObjectsV2Response.builder()
                .contents(S3Object.builder().key("exports/u/e.zip").build()).isTruncated(false).build());
        assertThat(storage.deletePrivatePrefixQuietly("exports/u/")).isEqualTo(1);
        ArgumentCaptor<ListObjectsV2Request> list = ArgumentCaptor.forClass(ListObjectsV2Request.class);
        verify(s3).listObjectsV2(list.capture());
        assertThat(list.getValue().bucket()).isEqualTo("exports-private");
        assertThat(list.getValue().prefix()).isEqualTo("exports/u/");
        assertThat(storage.deletePrivatePrefixQuietly("exports/u")).isZero();
    }

    @Test
    void neverBuildsPublicUrlsForPrivateKeys() {
        assertThat(storage.publicUrl("avatars/u/a.webp")).isEqualTo("https://cdn.example/media/avatars/u/a.webp");
        assertThatThrownBy(() -> storage.publicUrl("exports/u/e.zip")).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> storage.publicUrl("private/exports/u/e.zip"))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> storage.publicUrl(null)).isInstanceOf(IllegalArgumentException.class);
    }
}
