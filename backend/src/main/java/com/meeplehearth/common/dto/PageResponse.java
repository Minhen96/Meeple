package com.meeplehearth.common.dto;

import org.springframework.data.domain.Page;

import java.util.List;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Standard paginated response wrapper.
 * Shape: { "data": [...], "meta": { "page": 1, "limit": 20, "total": 150, "hasMore": true } }
 */
public record PageResponse<T>(List<T> data, PageMeta meta) {

    /**
     * Build from a Spring Data Page object.
     */
    public static <T> PageResponse<T> of(Page<T> page) {
        PageMeta meta = new PageMeta(
                page.getNumber() + 1,           // 1-based page number
                page.getSize(),
                page.getTotalElements(),
                page.hasNext()
        );
        return new PageResponse<>(page.getContent(), meta);
    }

    /**
     * Build from a Spring Data Page, mapping entities to DTOs.
     */
    public static <E, T> PageResponse<T> of(Page<E> page, Function<E, T> mapper) {
        List<T> mapped = page.getContent().stream().map(mapper).collect(Collectors.toList());
        PageMeta meta = new PageMeta(
                page.getNumber() + 1,
                page.getSize(),
                page.getTotalElements(),
                page.hasNext()
        );
        return new PageResponse<>(mapped, meta);
    }
}
