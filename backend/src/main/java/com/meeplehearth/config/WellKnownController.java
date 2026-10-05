package com.meeplehearth.config;

import com.meeplehearth.common.advice.RawResponse;
import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Duration;
import java.util.Arrays;
import java.util.List;
import java.util.Map;

/**
 * Universal links (iOS) and App Links (Android) verification files (FEATURES_COMPLETE section
 * 12.3), served unauthenticated as JSON. They are generated from configuration
 * ({@code app.deep-links.*}) so signing fingerprints and team ids never live in the repository;
 * without configuration both files are valid and list no apps.
 *
 * <p>The deep-link paths follow section 12.3 with C8 applied ({@code /library/{gameId}}).
 */
@RestController
@RawResponse
public class WellKnownController {

    static final List<String> APP_LINK_PATHS = List.of(
            "/library/*", "/events/*", "/posts/*", "/profile/*", "/notifications", "/posts/create");

    private final AppProperties appProperties;

    public WellKnownController(AppProperties appProperties) {
        this.appProperties = appProperties;
    }

    @GetMapping(value = "/.well-known/apple-app-site-association", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<Map<String, Object>> appleAppSiteAssociation() {
        String appId = appProperties.getDeepLinks().getIosAppId();
        List<Map<String, Object>> details = appId == null || appId.isBlank()
                ? List.of()
                : List.of(Map.of("appIDs", List.of(appId.trim()), "components", APP_LINK_PATHS.stream()
                        .map(path -> Map.of("/", path))
                        .toList()));
        return ResponseEntity.ok()
                .cacheControl(CacheControl.maxAge(Duration.ofHours(1)).cachePublic())
                .body(Map.of("applinks", Map.of("details", details)));
    }

    @GetMapping(value = "/.well-known/assetlinks.json", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<List<Map<String, Object>>> assetLinks() {
        AppProperties.DeepLinks links = appProperties.getDeepLinks();
        String packageName = links.getAndroidPackage();
        List<String> fingerprints = links.getAndroidSha256Fingerprints() == null
                ? List.of()
                : Arrays.stream(links.getAndroidSha256Fingerprints().split(","))
                        .map(String::trim)
                        .filter(f -> !f.isEmpty())
                        .toList();
        List<Map<String, Object>> statements = packageName == null || packageName.isBlank() || fingerprints.isEmpty()
                ? List.of()
                : List.of(Map.of(
                        "relation", List.of("delegate_permission/common.handle_all_urls"),
                        "target", Map.of(
                                "namespace", "android_app",
                                "package_name", packageName.trim(),
                                "sha256_cert_fingerprints", fingerprints)));
        return ResponseEntity.ok()
                .cacheControl(CacheControl.maxAge(Duration.ofHours(1)).cachePublic())
                .body(statements);
    }
}
