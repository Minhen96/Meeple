package com.meeplehearth.storage.controller;

import com.meeplehearth.config.AppProperties;
import com.meeplehearth.storage.StorageKeys;
import com.meeplehearth.support.auth.AuthWebIntegrationTest;
import com.meeplehearth.user.entity.User;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MvcResult;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectResponse;
import software.amazon.awssdk.services.s3.presigner.model.PresignedPutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.model.PutObjectPresignRequest;

import java.net.URI;
import java.time.Duration;
import java.util.Arrays;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Upload endpoints through the HTTP layer; only the R2 (S3) clients are mocked. */
class StorageControllerIntegrationTest extends AuthWebIntegrationTest {

    private static final byte[] PNG = {(byte) 0x89, 'P', 'N', 'G', '\r', '\n', 0x1A, '\n', 0, 0, 0, 13, 'I', 'H', 'D', 'R'};
    private static final byte[] JPEG = {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, (byte) 0xE0, 0, 16, 'J', 'F', 'I', 'F'};

    @Autowired private AppProperties appProperties;

    private MvcResult presign(User user, Object body) throws Exception {
        return mockMvc.perform(post("/api/v1/upload/presign").cookie(accessCookie(user))
                        .contentType(MediaType.APPLICATION_JSON).content(json(body)))
                .andReturn();
    }

    @Test
    void presignReturnsAnOwnedKeyAndSignsTypeAndLength() throws Exception {
        User user = persistUser(true);
        PresignedPutObjectRequest presigned = mock(PresignedPutObjectRequest.class);
        when(presigned.url()).thenReturn(URI.create("https://r2.example.test/signed?X-Amz-Signature=abc").toURL());
        when(s3Presigner.presignPutObject(any(PutObjectPresignRequest.class))).thenReturn(presigned);

        MvcResult result = presign(user, Map.of("contentType", "image/webp", "size", 2048));

        assertThat(result.getResponse().getStatus()).isEqualTo(200);
        String key = body(result).at("/data/key").asText();
        assertThat(StorageKeys.isOwnedUploadKey(key, user.getId())).isTrue();
        assertThat(key).endsWith(".webp");
        assertThat(body(result).at("/data/uploadUrl").asText()).isEqualTo("https://r2.example.test/signed?X-Amz-Signature=abc");
        assertThat(body(result).at("/data/publicUrl").asText()).isEqualTo(appProperties.getR2().getPublicUrl() + "/" + key);

        ArgumentCaptor<PutObjectPresignRequest> captor = ArgumentCaptor.forClass(PutObjectPresignRequest.class);
        verify(s3Presigner).presignPutObject(captor.capture());
        PutObjectRequest put = captor.getValue().putObjectRequest();
        assertThat(put.bucket()).isEqualTo(appProperties.getR2().getBucket());
        assertThat(put.key()).isEqualTo(key);
        assertThat(put.contentType()).isEqualTo("image/webp");
        assertThat(put.contentLength()).isEqualTo(2048L);
        assertThat(captor.getValue().signatureDuration()).isEqualTo(Duration.ofMinutes(10));
    }

    @Test
    void presignRejectsBadTypesSizesAndAnonymousCallers() throws Exception {
        User user = persistUser(true);

        MvcResult badType = presign(user, Map.of("contentType", "image/svg+xml", "size", 10));
        assertThat(badType.getResponse().getStatus()).isEqualTo(400);
        assertThat(body(badType).get("code").asText()).isEqualTo("VALIDATION_ERROR");
        assertThat(body(badType).get("error").asText()).contains("contentType");

        MvcResult negative = presign(user, Map.of("contentType", "image/png", "size", -1));
        assertThat(body(negative).get("code").asText()).isEqualTo("VALIDATION_ERROR");
        assertThat(body(negative).get("error").asText()).contains("size");

        MvcResult missingSize = presign(user, Map.of("contentType", "image/png"));
        assertThat(missingSize.getResponse().getStatus()).isEqualTo(400);

        MvcResult tooLarge = presign(user, Map.of("contentType", "image/png",
                "size", appProperties.getStorage().getMaxUploadBytes() + 1));
        assertThat(tooLarge.getResponse().getStatus()).isEqualTo(413);
        assertThat(body(tooLarge).get("code").asText()).isEqualTo("FILE_TOO_LARGE");
        assertThat(body(tooLarge).get("error").asText()).contains("10 MB");

        mockMvc.perform(post("/api/v1/upload/presign").contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("contentType", "image/png", "size", 10))))
                .andExpect(status().isUnauthorized());
        verifyNoInteractions(s3Presigner);
    }

    @Test
    void multipartUploadStoresDetectedTypeUnderTheUsersPrefix() throws Exception {
        User user = persistUser(true);
        // Declared as GIF, content is PNG: the content wins
        MockMultipartFile file = new MockMultipartFile("file", "cat.gif", "image/gif", PNG);

        MvcResult result = mockMvc.perform(multipart("/api/v1/upload").file(file).cookie(accessCookie(user))).andReturn();

        assertThat(result.getResponse().getStatus()).isEqualTo(200);
        String key = body(result).at("/data/key").asText();
        assertThat(StorageKeys.isOwnedUploadKey(key, user.getId())).isTrue();
        assertThat(key).endsWith(".png");
        assertThat(body(result).at("/data/publicUrl").asText()).endsWith("/" + key);

        ArgumentCaptor<PutObjectRequest> request = ArgumentCaptor.forClass(PutObjectRequest.class);
        ArgumentCaptor<RequestBody> content = ArgumentCaptor.forClass(RequestBody.class);
        verify(s3Client).putObject(request.capture(), content.capture());
        assertThat(request.getValue().key()).isEqualTo(key);
        assertThat(request.getValue().contentType()).isEqualTo("image/png");
        assertThat(request.getValue().contentLength()).isEqualTo((long) PNG.length);
        assertThat(content.getValue().contentStreamProvider().newStream().readAllBytes()).isEqualTo(PNG);
    }

    @Test
    void avatarUploadUsesTheAvatarPrefix() throws Exception {
        User user = persistUser(true);
        when(s3Client.putObject(any(PutObjectRequest.class), any(RequestBody.class)))
                .thenReturn(PutObjectResponse.builder().build());

        MvcResult result = mockMvc.perform(multipart("/api/v1/upload/avatar")
                        .file(new MockMultipartFile("file", "me.jpg", "image/jpeg", JPEG))
                        .cookie(accessCookie(user)))
                .andReturn();

        assertThat(result.getResponse().getStatus()).isEqualTo(200);
        String url = body(result).at("/data/publicUrl").asText();
        assertThat(url).startsWith(appProperties.getR2().getPublicUrl() + "/avatars/" + user.getId() + "/").endsWith(".jpg");
        assertThat(body(result).at("/data/key").isMissingNode()).isTrue();
    }

    @Test
    void uploadsRejectEmptyOversizedAndNonImageFiles() throws Exception {
        User user = persistUser(true);

        MvcResult empty = mockMvc.perform(multipart("/api/v1/upload")
                        .file(new MockMultipartFile("file", "x.png", "image/png", new byte[0])).cookie(accessCookie(user)))
                .andReturn();
        assertThat(empty.getResponse().getStatus()).isEqualTo(400);
        assertThat(body(empty).get("code").asText()).isEqualTo("EMPTY_FILE");

        MvcResult script = mockMvc.perform(multipart("/api/v1/upload/avatar")
                        .file(new MockMultipartFile("file", "x.png", "image/png", "<script>alert(1)</script>".getBytes()))
                        .cookie(accessCookie(user)))
                .andReturn();
        assertThat(script.getResponse().getStatus()).isEqualTo(400);
        assertThat(body(script).get("code").asText()).isEqualTo("UNSUPPORTED_CONTENT_TYPE");

        byte[] huge = Arrays.copyOf(PNG, (int) appProperties.getStorage().getMaxUploadBytes() + 1);
        MvcResult tooLarge = mockMvc.perform(multipart("/api/v1/upload")
                        .file(new MockMultipartFile("file", "big.png", "image/png", huge)).cookie(accessCookie(user)))
                .andReturn();
        assertThat(tooLarge.getResponse().getStatus()).isEqualTo(413);
        assertThat(body(tooLarge).get("code").asText()).isEqualTo("FILE_TOO_LARGE");

        mockMvc.perform(multipart("/api/v1/upload").file(new MockMultipartFile("file", "x.png", "image/png", PNG)))
                .andExpect(status().isUnauthorized());
        verify(s3Client, never()).putObject(any(PutObjectRequest.class), any(RequestBody.class));
    }
}
