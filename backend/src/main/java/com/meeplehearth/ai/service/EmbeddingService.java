package com.meeplehearth.ai.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.meeplehearth.config.AppProperties;
import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import org.springframework.http.HttpHeaders;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

@Service
public class EmbeddingService {

    private final AppProperties appProperties;
    private final RestClient restClient;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public EmbeddingService(AppProperties appProperties) {
        this.appProperties = appProperties;

        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(10_000);
        factory.setReadTimeout(30_000);

        this.restClient = RestClient.builder()
                .baseUrl(appProperties.getAi().getEmbedding().getBaseUrl())
                .requestFactory(factory)
                .build();
    }

    /**
     * Embed a text string using the configured embedding model.
     * Returns a float[1536] vector (text-embedding-3-small dimensions).
     */
    @CircuitBreaker(name = "openai")
    public float[] embed(String text) {
        try {
            String body = "{\"model\":\"%s\",\"input\":%s}".formatted(
                    appProperties.getAi().getEmbedding().getModel(),
                    objectMapper.writeValueAsString(text)
            );

            String response = restClient.post()
                    .uri("/v1/embeddings")
                    .header(HttpHeaders.AUTHORIZATION, "Bearer " + appProperties.getAi().getEmbedding().getApiKey())
                    .header(HttpHeaders.CONTENT_TYPE, "application/json")
                    .body(body)
                    .retrieve()
                    .body(String.class);

            JsonNode embeddingArray = objectMapper.readTree(response)
                    .path("data").get(0).path("embedding");

            float[] result = new float[embeddingArray.size()];
            for (int i = 0; i < embeddingArray.size(); i++) {
                result[i] = (float) embeddingArray.get(i).asDouble();
            }
            return result;

        } catch (Exception e) {
            throw new RuntimeException("Embedding failed: " + e.getMessage(), e);
        }
    }

    /**
     * Converts float[] to pgvector literal format: [v1,v2,...,v1536]
     * Use this when setting RuleChunk.embedding for persistence.
     */
    public static String toVectorString(float[] embedding) {
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < embedding.length; i++) {
            sb.append(embedding[i]);
            if (i < embedding.length - 1) sb.append(",");
        }
        sb.append("]");
        return sb.toString();
    }
}
