package com.meeplehearth.user;

import com.fasterxml.jackson.databind.JsonNode;
import com.meeplehearth.user.service.AccountMailer;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.UUID;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.timeout;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** GET /users/me/export: 202, async zip to R2, emailed presigned link, one export per day. */
class DataExportFeatureTest extends AccountFeatureTestBase {

    @MockitoBean S3Client s3Client;
    @MockitoBean AccountMailer mailer;

    private String waitForStatus(UUID exportId, String expected) throws InterruptedException {
        String status = null;
        for (int i = 0; i < 100; i++) {
            status = string("SELECT status FROM data_export_requests WHERE id = ?", exportId);
            if (expected.equals(status)) {
                return status;
            }
            Thread.sleep(100);
        }
        return status;
    }

    @Test
    void buildsZipStoresItAndEmailsTheLink() throws Exception {
        UUID userId = passwordUser();
        UUID game = game();
        jdbc.update("INSERT INTO user_games (user_id, game_id, is_owned) VALUES (?, ?, true)", userId, game);

        JsonNode body = json(mvc.perform(get("/api/v1/users/me/export").with(as(userId)))
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.data.status").value("PENDING"))
                .andReturn());
        UUID exportId = UUID.fromString(body.get("data").get("id").asText());

        assertThat(waitForStatus(exportId, "COMPLETED")).isEqualTo("COMPLETED");
        ArgumentCaptor<PutObjectRequest> put = ArgumentCaptor.forClass(PutObjectRequest.class);
        ArgumentCaptor<RequestBody> content = ArgumentCaptor.forClass(RequestBody.class);
        verify(s3Client).putObject(put.capture(), content.capture());
        assertThat(put.getValue().key()).isEqualTo("exports/" + userId + "/" + exportId + ".zip");
        assertThat(put.getValue().contentType()).isEqualTo("application/zip");

        String exported = unzip(content.getValue());
        JsonNode export = objectMapper.readTree(exported);
        assertThat(export.get("profile").get("id").asText()).isEqualTo(userId.toString());
        assertThat(export.get("collection")).hasSize(1);
        assertThat(export.get("posts")).isEmpty();
        assertThat(exported).doesNotContain("password").doesNotContain("$2a$");

        verify(mailer, timeout(5000)).sendExportReady(eq(userId), anyString(), anyString(),
                org.mockito.ArgumentMatchers.contains("exports/" + userId), any(Duration.class));
        assertThat(string("SELECT file_key FROM data_export_requests WHERE id = ?", exportId))
                .isEqualTo("exports/" + userId + "/" + exportId + ".zip");

        // Asking again within 24 hours returns the same export
        mvc.perform(get("/api/v1/users/me/export").with(as(userId)))
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.data.id").value(exportId.toString()))
                .andExpect(jsonPath("$.data.status").value("COMPLETED"));
    }

    @Test
    void storageFailureMarksTheExportFailedAndAllowsARetry() throws Exception {
        UUID userId = passwordUser();
        when(s3Client.putObject(any(PutObjectRequest.class), any(RequestBody.class)))
                .thenThrow(new IllegalStateException("R2 down"));

        UUID first = UUID.fromString(json(mvc.perform(get("/api/v1/users/me/export").with(as(userId)))
                .andExpect(status().isAccepted()).andReturn()).get("data").get("id").asText());
        assertThat(waitForStatus(first, "FAILED")).isEqualTo("FAILED");

        UUID second = UUID.fromString(json(mvc.perform(get("/api/v1/users/me/export").with(as(userId)))
                .andExpect(status().isAccepted()).andReturn()).get("data").get("id").asText());
        assertThat(second).isNotEqualTo(first);
        assertThat(waitForStatus(second, "FAILED")).isEqualTo("FAILED");
    }

    private static String unzip(RequestBody body) throws Exception {
        byte[] bytes = body.contentStreamProvider().newStream().readAllBytes();
        try (ZipInputStream zip = new ZipInputStream(new ByteArrayInputStream(bytes))) {
            ZipEntry entry = zip.getNextEntry();
            assertThat(entry).isNotNull();
            assertThat(entry.getName()).isEqualTo("meeple-export.json");
            return new String(zip.readAllBytes(), StandardCharsets.UTF_8);
        }
    }
}
