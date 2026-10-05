package com.meeplehearth.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.serializer.GenericJackson2JsonRedisSerializer;
import org.springframework.http.converter.json.Jackson2ObjectMapperBuilder;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class CacheConfigTest {

    record Nested(UUID id, String name) {
    }

    record CachedDto(UUID id, String title, Instant createdAt, BigDecimal rating, boolean owned,
                     List<Nested> items, List<String> tags, Map<String, Object> extra) {
    }

    private final GenericJackson2JsonRedisSerializer serializer =
            CacheConfig.cacheValueSerializer(Jackson2ObjectMapperBuilder.json().build());

    @Test
    void recordsWithJavaTimeAndImmutableCollectionsRoundTrip() {
        CachedDto dto = new CachedDto(UUID.randomUUID(), "Catan", Instant.parse("2026-01-02T03:04:05Z"),
                new BigDecimal("7.25"), true,
                List.of(new Nested(UUID.randomUUID(), "a"), new Nested(UUID.randomUUID(), "b")),
                new ArrayList<>(List.of("x", "y")), Map.of("count", 3));

        Object restored = serializer.deserialize(serializer.serialize(dto));

        assertThat(restored).isEqualTo(dto);
    }

    @Test
    void listOfRecordsRoundTrips() {
        List<Nested> list = List.of(new Nested(UUID.randomUUID(), "only"));

        Object restored = serializer.deserialize(serializer.serialize(list));

        assertThat(restored).isEqualTo(list);
    }

    @Test
    void doesNotChangeTheApplicationObjectMapper() {
        ObjectMapper appMapper = Jackson2ObjectMapperBuilder.json().build();
        CacheConfig.cacheValueSerializer(appMapper);

        assertThat(appMapper.getPolymorphicTypeValidator().getClass().getSimpleName())
                .isNotEqualTo("BasicPolymorphicTypeValidator");
    }
}
