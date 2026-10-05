package com.meeplehearth.game.service;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import org.springframework.http.ResponseEntity;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

/**
 * HEAD probe for the seed CSV URL (admin setup page).
 * Lives in its own bean so the "seedCsv" circuit breaker proxy applies.
 */
@Service
public class SeedCsvProbeService {

    private final RestClient client;

    public SeedCsvProbeService() {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(8_000);
        factory.setReadTimeout(8_000);
        this.client = RestClient.builder().requestFactory(factory).build();
    }

    public record CsvProbe(int httpStatus, String contentType, long contentLength) {}

    @CircuitBreaker(name = "seedCsv", fallbackMethod = "probeFallback")
    public CsvProbe probe(String csvUrl) {
        ResponseEntity<Void> response = client.head().uri(csvUrl).retrieve().toBodilessEntity();
        return new CsvProbe(
                response.getStatusCode().value(),
                response.getHeaders().getFirst("Content-Type"),
                response.getHeaders().getContentLength());
    }

    @SuppressWarnings("unused")
    private CsvProbe probeFallback(String csvUrl, Throwable t) {
        throw new IllegalStateException(t.getMessage(), t);
    }
}
