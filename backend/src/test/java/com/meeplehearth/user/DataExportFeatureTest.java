package com.meeplehearth.user;

import com.fasterxml.jackson.databind.JsonNode;
import com.meeplehearth.config.AppProperties;
import com.meeplehearth.user.job.DataExportCleanupJob;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import software.amazon.awssdk.services.s3.model.DeleteObjectsRequest;
import org.mockito.ArgumentCaptor;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.UUID;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.timeout;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** POST /users/me/export: 202, async zip to R2, emailed presigned link, one export per day. */
class DataExportFeatureTest extends AccountFeatureTestBase {

    @Autowired private AppProperties appProperties;
    @Autowired private DataExportCleanupJob cleanupJob;


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

        JsonNode body = json(mvc.perform(post("/api/v1/users/me/export").with(as(userId)))
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.data.status").value("PENDING"))
                .andReturn());
        UUID exportId = UUID.fromString(body.get("data").get("id").asText());

        assertThat(waitForStatus(exportId, "COMPLETED")).isEqualTo("COMPLETED");
        ArgumentCaptor<PutObjectRequest> put = ArgumentCaptor.forClass(PutObjectRequest.class);
        ArgumentCaptor<RequestBody> content = ArgumentCaptor.forClass(RequestBody.class);
        verify(s3Client).putObject(put.capture(), content.capture());
        // No private bucket in tests: the fallback prefix in the media bucket, never a public URL
        assertThat(put.getValue().key()).isEqualTo("private/exports/" + userId + "/" + exportId + ".zip");
        assertThat(put.getValue().contentType()).isEqualTo("application/zip");

        String exported = unzip(content.getValue());
        JsonNode export = objectMapper.readTree(exported);
        assertThat(export.get("profile").get("id").asText()).isEqualTo(userId.toString());
        assertThat(export.get("collection")).hasSize(1);
        assertThat(export.get("posts")).isEmpty();
        assertThat(exported).doesNotContain("password").doesNotContain("$2a$");

        verify(mailer, timeout(5000)).sendExportReady(eq(userId), anyString(), anyString(),
                org.mockito.ArgumentMatchers.contains("private/exports/" + userId), any(Duration.class));
        ArgumentCaptor<String> link = ArgumentCaptor.forClass(String.class);
        verify(mailer).sendExportReady(eq(userId), anyString(), anyString(), link.capture(), any(Duration.class));
        assertThat(link.getValue()).contains("X-Amz-Signature")
                .doesNotStartWith(appProperties.getR2().getPublicUrl());
        assertThat(string("SELECT file_key FROM data_export_requests WHERE id = ?", exportId))
                .isEqualTo("exports/" + userId + "/" + exportId + ".zip");

        // Asking again within 24 hours returns the same export
        mvc.perform(post("/api/v1/users/me/export").with(as(userId)))
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.data.id").value(exportId.toString()))
                .andExpect(jsonPath("$.data.status").value("COMPLETED"));
    }

    @Test
    void storageFailureMarksTheExportFailedAndAllowsARetry() throws Exception {
        UUID userId = passwordUser();
        when(s3Client.putObject(any(PutObjectRequest.class), any(RequestBody.class)))
                .thenThrow(new IllegalStateException("R2 down"));

        UUID first = UUID.fromString(json(mvc.perform(post("/api/v1/users/me/export").with(as(userId)))
                .andExpect(status().isAccepted()).andReturn()).get("data").get("id").asText());
        assertThat(waitForStatus(first, "FAILED")).isEqualTo("FAILED");

        UUID second = UUID.fromString(json(mvc.perform(post("/api/v1/users/me/export").with(as(userId)))
                .andExpect(status().isAccepted()).andReturn()).get("data").get("id").asText());
        assertThat(second).isNotEqualTo(first);
        assertThat(waitForStatus(second, "FAILED")).isEqualTo("FAILED");
    }

    @Test
    void getIsNotAllowed() throws Exception {
        UUID userId = passwordUser();
        mvc.perform(get("/api/v1/users/me/export").with(as(userId)))
                .andExpect(status().isMethodNotAllowed());
        assertThat(count("SELECT COUNT(*) FROM data_export_requests WHERE user_id = ?", userId)).isZero();
    }

    @Test
    void cleanupDeletesExportsOlderThanSevenDaysAndMarksThemExpired() {
        UUID userId = passwordUser();
        UUID old = export(userId, "COMPLETED", Instant.now().minus(Duration.ofDays(8)));
        UUID recent = export(userId, "COMPLETED", Instant.now().minus(Duration.ofDays(2)));
        UUID failed = export(userId, "FAILED", Instant.now().minus(Duration.ofDays(9)));

        assertThat(cleanupJob.cleanUp()).isGreaterThanOrEqualTo(1);

        ArgumentCaptor<DeleteObjectsRequest> delete = ArgumentCaptor.forClass(DeleteObjectsRequest.class);
        verify(s3Client, atLeastOnce()).deleteObjects(delete.capture());
        assertThat(delete.getAllValues().stream().flatMap(d -> d.delete().objects().stream())
                .map(o -> o.key()))
                .contains("private/exports/" + userId + "/" + old + ".zip")
                .doesNotContain("private/exports/" + userId + "/" + recent + ".zip");
        assertThat(string("SELECT status FROM data_export_requests WHERE id = ?", old)).isEqualTo("EXPIRED");
        assertThat(string("SELECT file_key FROM data_export_requests WHERE id = ?", old)).isNull();
        assertThat(string("SELECT status FROM data_export_requests WHERE id = ?", recent)).isEqualTo("COMPLETED");
        assertThat(string("SELECT status FROM data_export_requests WHERE id = ?", failed)).isEqualTo("FAILED");
        cleanupJob.run();
    }

    @Test
    void cleanupKeepsRequestsWhenStorageFails() {
        UUID userId = passwordUser();
        UUID old = export(userId, "COMPLETED", Instant.now().minus(Duration.ofDays(8)));
        when(s3Client.deleteObjects(any(DeleteObjectsRequest.class))).thenThrow(new IllegalStateException("R2 down"));

        assertThat(cleanupJob.cleanUp()).isZero();
        assertThat(string("SELECT status FROM data_export_requests WHERE id = ?", old)).isEqualTo("COMPLETED");
    }

    private UUID export(UUID userId, String status, Instant completedAt) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO data_export_requests (id, user_id, status, file_key, created_at, completed_at)"
                        + " VALUES (?, ?, ?, ?, ?, ?)", id, userId, status,
                "exports/" + userId + "/" + id + ".zip", ts(completedAt), ts(completedAt));
        return id;
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
