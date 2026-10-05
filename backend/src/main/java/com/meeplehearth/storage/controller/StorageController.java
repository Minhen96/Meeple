package com.meeplehearth.storage.controller;

import com.meeplehearth.config.AppProperties;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.storage.ImageType;
import com.meeplehearth.storage.StorageKeys;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import org.springframework.http.HttpStatus;
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
import java.util.Arrays;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/upload")
@Validated
public class StorageController {

    private static final Duration PRESIGN_EXPIRY = Duration.ofMinutes(10);
    private static final String UNSUPPORTED_TYPE_MESSAGE =
            "Only JPEG, PNG, WebP and GIF images are allowed";

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
     * Content-Type and Content-Length are part of the signature, so the PUT must send exactly
     * the declared type and size (browsers set Content-Length from the File automatically).
     *
     * Body: { "contentType": "image/jpeg", "size": 123456 }
     * Response: { "uploadUrl": "https://...", "key": "uploads/<userId>/<uuid>.jpg",
     * "publicUrl": "https://cdn.../..." }
     */
    @PostMapping("/presign")
    public ResponseEntity<Map<String, String>> presign(
            @RequestBody @Validated PresignRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {

        ImageType type = ImageType.fromContentType(request.contentType())
                .orElseThrow(() -> ApiException.badRequest("UNSUPPORTED_CONTENT_TYPE", UNSUPPORTED_TYPE_MESSAGE));
        requireAllowedSize(request.size());

        String key = StorageKeys.newUploadKey(UUID.fromString(userDetails.getUsername()), type);
        String uploadUrl = presignPut(key, type, request.size());
        String publicUrl = appProperties.getR2().getPublicUrl() + "/" + key;

        return ResponseEntity.ok(Map.of(
                "uploadUrl", uploadUrl,
                "key", key,
                "publicUrl", publicUrl));
    }

    String presignPut(String key, ImageType type, long size) {
        PutObjectRequest putObjectRequest = PutObjectRequest.builder()
                .bucket(appProperties.getR2().getBucket())
                .key(key)
                .contentType(type.contentType())
                .contentLength(size)
                .build();

        PutObjectPresignRequest presignRequest = PutObjectPresignRequest.builder()
                .signatureDuration(PRESIGN_EXPIRY)
                .putObjectRequest(putObjectRequest)
                .build();

        return s3Presigner.presignPutObject(presignRequest).url().toString();
    }

    /**
     * POST /api/v1/upload (multipart/form-data, field: "file")
     *
     * Generic direct upload to the backend, bypassing browser CORS.
     * The image type is detected from the file content; the declared Content-Type is ignored.
     * Response: { "publicUrl": "https://...", "key": "uploads/<userId>/<uuid>.<ext>" }
     */
    @PostMapping(value = "", consumes = "multipart/form-data")
    public ResponseEntity<Map<String, String>> upload(
            @RequestPart("file") MultipartFile file,
            @AuthenticationPrincipal UserDetails userDetails) throws IOException {

        byte[] content = readValidatedImage(file);
        ImageType type = detectImageType(content);
        String key = StorageKeys.newUploadKey(UUID.fromString(userDetails.getUsername()), type);
        putObject(key, type, content);

        String publicUrl = appProperties.getR2().getPublicUrl() + "/" + key;
        return ResponseEntity.ok(Map.of(
                "publicUrl", publicUrl,
                "key", key
        ));
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

        byte[] content = readValidatedImage(file);
        ImageType type = detectImageType(content);
        String key = StorageKeys.newAvatarKey(UUID.fromString(userDetails.getUsername()), type);
        putObject(key, type, content);

        String publicUrl = appProperties.getR2().getPublicUrl() + "/" + key;
        return ResponseEntity.ok(Map.of("publicUrl", publicUrl));
    }

    private byte[] readValidatedImage(MultipartFile file) throws IOException {
        requireAllowedSize(file.getSize());
        byte[] content = file.getBytes();
        requireAllowedSize(content.length);
        return content;
    }

    static ImageType detectImageType(byte[] content) {
        byte[] header = Arrays.copyOf(content, Math.min(content.length, ImageType.SIGNATURE_LENGTH));
        return ImageType.detect(header)
                .orElseThrow(() -> ApiException.badRequest("UNSUPPORTED_CONTENT_TYPE", UNSUPPORTED_TYPE_MESSAGE));
    }

    private void requireAllowedSize(long size) {
        if (size <= 0) {
            throw ApiException.badRequest("EMPTY_FILE", "File is empty");
        }
        long max = appProperties.getStorage().getMaxUploadBytes();
        if (size > max) {
            throw new ApiException(HttpStatus.PAYLOAD_TOO_LARGE, "FILE_TOO_LARGE",
                    "File exceeds the maximum upload size of " + (max / (1024 * 1024)) + " MB");
        }
    }

    private void putObject(String key, ImageType type, byte[] content) {
        PutObjectRequest putRequest = PutObjectRequest.builder()
                .bucket(appProperties.getR2().getBucket())
                .key(key)
                .contentType(type.contentType())
                .contentLength((long) content.length)
                .build();

        s3Client.putObject(putRequest, software.amazon.awssdk.core.sync.RequestBody.fromBytes(content));
    }

    public record PresignRequest(
            @NotBlank @Pattern(regexp = "image/(jpeg|png|webp|gif)", message = "contentType must be one of: image/jpeg, image/png, image/webp, image/gif") String contentType,
            @NotNull @Positive Long size) {
    }
}
