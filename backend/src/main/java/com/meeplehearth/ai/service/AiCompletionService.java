package com.meeplehearth.ai.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.meeplehearth.config.AppProperties;
import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import org.springframework.http.HttpHeaders;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.List;
import java.util.Map;

/**
 * Provider-agnostic chat completion service.
 *
 * Works with any OpenAI-compatible REST API (OpenAI, DeepSeek, Groq, Together).
 * All config comes from app.ai.completion.* — nothing hardcoded here.
 */
@Service
public class AiCompletionService {

    private final AppProperties appProperties;
    private final RestClient restClient;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public AiCompletionService(AppProperties appProperties) {
        this.appProperties = appProperties;

        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(10_000);
        factory.setReadTimeout(60_000);

        this.restClient = RestClient.builder()
                .baseUrl(appProperties.getAi().getCompletion().getBaseUrl())
                .requestFactory(factory)
                .build();
    }

    /**
     * Send a message list to the completion API and return the reply text.
     *
     * @param messages    ordered list of {role: "system"|"user"|"assistant", content: "..."}
     * @param maxTokens   max tokens for the reply
     * @param temperature 0.0 = deterministic, 1.0 = creative
     */
    @CircuitBreaker(name = "openai")
    public String complete(List<Map<String, String>> messages, int maxTokens, double temperature) {
        try {
            String body = objectMapper.writeValueAsString(Map.of(
                    "model", appProperties.getAi().getCompletion().getModel(),
                    "messages", messages,
                    "max_tokens", maxTokens,
                    "temperature", temperature
            ));

            String response = restClient.post()
                    .uri("/v1/chat/completions")
                    .header(HttpHeaders.AUTHORIZATION, "Bearer " + appProperties.getAi().getCompletion().getApiKey())
                    .header(HttpHeaders.CONTENT_TYPE, "application/json")
                    .body(body)
                    .retrieve()
                    .body(String.class);

            return objectMapper.readTree(response)
                    .path("choices").get(0).path("message").path("content").asText();

        } catch (Exception e) {
            throw new RuntimeException("Completion failed: " + e.getMessage(), e);
        }
    }
}
