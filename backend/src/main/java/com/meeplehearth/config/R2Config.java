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
        return S3Client.builder()
                .endpointOverride(URI.create(r2.getEndpoint()))
                .region(Region.of("auto"))
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(r2.getAccessKey(), r2.getSecretKey())
                ))
                .build();
    }

    @Bean
    public S3Presigner s3Presigner() {
        AppProperties.R2 r2 = appProperties.getR2();
        return S3Presigner.builder()
                .endpointOverride(URI.create(r2.getEndpoint()))
                .region(Region.of("auto"))
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(r2.getAccessKey(), r2.getSecretKey())
                ))
                .build();
    }
}
