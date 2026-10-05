package com.meeplehearth.storage.controller;

import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.config.AppProperties;
import com.meeplehearth.storage.ImageType;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;

import java.net.URI;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

class StorageControllerTest {

    private final UUID userId = UUID.randomUUID();
    private final UserDetails principal = User.withUsername(userId.toString()).password("").authorities("ROLE_USER").build();
    private final S3Client s3Client = mock(S3Client.class);

    private StorageController controller() {
        AppProperties props = new AppProperties();
        props.getR2().setBucket("meeple-media");
        props.getR2().setPublicUrl("https://cdn.example.com");
        props.getStorage().setMaxUploadBytes(1024);
        S3Presigner presigner = S3Presigner.builder()
                .region(Region.US_EAST_1)
                .endpointOverride(URI.create("https://r2.example.com"))
                .credentialsProvider(StaticCredentialsProvider.create(AwsBasicCredentials.create("key", "secret")))
                .serviceConfiguration(S3Configuration.builder().pathStyleAccessEnabled(true).build())
                .build();
        return new StorageController(presigner, s3Client, props);
    }

    @Test
    void presignedUrlSignsContentLengthAndContentType() {
        Map<String, String> body = controller()
                .presign(new StorageController.PresignRequest("image/png", 512L), principal)
                .getBody();

        assertThat(body).isNotNull();
        assertThat(body.get("key")).startsWith("uploads/" + userId + "/").endsWith(".png");
        String signedHeaders = URLDecoder.decode(body.get("uploadUrl"), StandardCharsets.UTF_8);
        assertThat(signedHeaders).contains("X-Amz-SignedHeaders=").contains("content-length").contains("content-type");
    }

    @Test
    void presignRejectsSizeAboveLimit() {
        assertThatThrownBy(() -> controller()
                .presign(new StorageController.PresignRequest("image/png", 4096L), principal))
                .isInstanceOf(ApiException.class)
                .extracting("status").isEqualTo(HttpStatus.PAYLOAD_TOO_LARGE);
    }

    @Test
    void multipartUploadRejectsContentThatIsNotAnImage() {
        MockMultipartFile disguised = new MockMultipartFile("file", "cat.png", "image/png",
                "<svg onload=alert(1)>".getBytes(StandardCharsets.UTF_8));

        assertThatThrownBy(() -> controller().upload(disguised, principal))
                .isInstanceOf(ApiException.class)
                .extracting("code").isEqualTo("UNSUPPORTED_CONTENT_TYPE");
        verify(s3Client, never()).putObject(any(PutObjectRequest.class), any(RequestBody.class));
    }

    @Test
    void multipartUploadUsesDetectedTypeNotDeclaredType() throws Exception {
        byte[] png = {(byte) 0x89, 'P', 'N', 'G', '\r', '\n', 0x1A, '\n', 0, 0, 0, 0};
        MockMultipartFile mislabelled = new MockMultipartFile("file", "x.gif", "image/gif", png);

        Map<String, String> body = controller().upload(mislabelled, principal).getBody();

        assertThat(body).isNotNull();
        assertThat(body.get("key")).endsWith(".png");
        assertThat(StorageController.detectImageType(png)).isEqualTo(ImageType.PNG);
    }
}
