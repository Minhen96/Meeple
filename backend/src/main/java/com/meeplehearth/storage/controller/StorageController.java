package com.meeplehearth.storage.controller;

import com.meeplehearth.config.AppProperties;
import com.meeplehearth.common.exception.ApiException;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.PutObjectPresignRequest;

import java.io.IOException;
import java.time.Duration;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/upload")
@Validated
public class StorageController {

    private static final Duration PRESIGN_EXPIRY = Duration.ofMinutes(10);
    private static final Set<String> ALLOWED_TYPES = Set.of("image/jpeg", "image/png", "image/webp", "image/gif");

    private final S3Presigner s3Presigner;
    private final S3Client s3Client;
    private final AppProperties appProperties;

    public StorageController(S3Presigner s3Presigner, S3Client s3Client, AppProperties appProperties) {
        this.s3Presigner = s3Presigner;
        this.s3Client = s3Client;
        this.appProperties = appProperties;
    }

    /**
     * POST /api/v1/upload/presign
     *
     * Returns a presigned PUT URL for direct Cloudflare R2 upload.
     * Client uploads directly to R2, then passes the returned key to the API.
     *
     * Body: { "contentType": "image/jpeg" }
     * Response: { "uploadUrl": "https://...", "key": "uploads/uuid/uuid.jpg",
     * "publicUrl": "https://cdn.../..." }
     */
    @PostMapping("/presign")
    public ResponseEntity<Map<String, String>> presign(
            @RequestBody @Validated PresignRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {

        String ext = extensionFor(request.contentType());
        String key = "uploads/" + userDetails.getUsername() + "/" + UUID.randomUUID() + "." + ext;

        PutObjectRequest putObjectRequest = PutObjectRequest.builder()
                .bucket(appProperties.getR2().getBucket())
                .key(key)
                .contentType(request.contentType())
                .build();

        PutObjectPresignRequest presignRequest = PutObjectPresignRequest.builder()
                .signatureDuration(PRESIGN_EXPIRY)
                .putObjectRequest(putObjectRequest)
                .build();

        String uploadUrl = s3Presigner.presignPutObject(presignRequest).url().toString();
        String publicUrl = appProperties.getR2().getPublicUrl() + "/" + key;

        return ResponseEntity.ok(Map.of(
                "uploadUrl", uploadUrl,
                "key", key,
                "publicUrl", publicUrl));
    }

    /**
     * POST /api/v1/upload/avatar  (multipart/form-data, field: "file")
     *
     * Uploads an avatar image directly from the backend to R2, bypassing browser CORS.
     * Response: { "publicUrl": "https://cdn.../..." }
     */
    @PostMapping(value = "/avatar", consumes = "multipart/form-data")
    public ResponseEntity<Map<String, String>> uploadAvatar(
            @RequestPart("file") MultipartFile file,
            @AuthenticationPrincipal UserDetails userDetails) throws IOException {

        String contentType = file.getContentType();
        if (contentType == null || !ALLOWED_TYPES.contains(contentType)) {
            throw ApiException.badRequest("UNSUPPORTED_CONTENT_TYPE",
                    "Only image/jpeg, image/png, image/webp, and image/gif are allowed");
        }

        String ext = extensionFor(contentType);
        String key = "avatars/" + userDetails.getUsername() + "/" + UUID.randomUUID() + "." + ext;

        PutObjectRequest putRequest = PutObjectRequest.builder()
                .bucket(appProperties.getR2().getBucket())
                .key(key)
                .contentType(contentType)
                .contentLength(file.getSize())
                .build();

        s3Client.putObject(putRequest,
                software.amazon.awssdk.core.sync.RequestBody.fromBytes(file.getBytes()));

        String publicUrl = appProperties.getR2().getPublicUrl() + "/" + key;
        return ResponseEntity.ok(Map.of("publicUrl", publicUrl));
    }

    private String extensionFor(String contentType) {
        return switch (contentType) {
            case "image/jpeg" -> "jpg";
            case "image/png" -> "png";
            case "image/webp" -> "webp";
            case "image/gif" -> "gif";
            default -> throw ApiException.badRequest("UNSUPPORTED_CONTENT_TYPE",
                    "Only image/jpeg, image/png, image/webp, and image/gif are allowed");
        };
    }

    public record PresignRequest(
            @NotBlank @Pattern(regexp = "image/(jpeg|png|webp|gif)", message = "contentType must be one of: image/jpeg, image/png, image/webp, image/gif") String contentType) {
    }
}
