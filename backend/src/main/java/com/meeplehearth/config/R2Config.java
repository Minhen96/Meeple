package com.meeplehearth.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;

import java.net.URI;

@Configuration
public class R2Config {

    private final AppProperties appProperties;

    public R2Config(AppProperties appProperties) {
        this.appProperties = appProperties;
    }

    @Bean
    public S3Client s3Client() {
        AppProperties.R2 r2 = appProperties.getR2();
        String endpoint   = blankSafe(r2.getEndpoint(),   "https://placeholder.r2.dev");
        String accessKey  = blankSafe(r2.getAccessKey(),  "placeholder");
        String secretKey  = blankSafe(r2.getSecretKey(),  "placeholder");
        return S3Client.builder()
                .endpointOverride(URI.create(endpoint))
                .region(Region.of("auto"))
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(accessKey, secretKey)
                ))
                .build();
    }

    @Bean
    public S3Presigner s3Presigner() {
        AppProperties.R2 r2 = appProperties.getR2();
        String endpoint   = blankSafe(r2.getEndpoint(),   "https://placeholder.r2.dev");
        String accessKey  = blankSafe(r2.getAccessKey(),  "placeholder");
        String secretKey  = blankSafe(r2.getSecretKey(),  "placeholder");
        return S3Presigner.builder()
                .endpointOverride(URI.create(endpoint))
                .region(Region.of("auto"))
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(accessKey, secretKey)
                ))
                .build();
    }

    private static String blankSafe(String value, String fallback) {
        return (value != null && !value.isBlank()) ? value : fallback;
    }
}
