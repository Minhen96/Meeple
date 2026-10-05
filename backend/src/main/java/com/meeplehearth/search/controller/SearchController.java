package com.meeplehearth.search.controller;

import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.search.dto.SearchResponse;
import com.meeplehearth.search.service.SearchService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Locale;
import java.util.UUID;

@RestController
public class SearchController {

    private final SearchService searchService;

    public SearchController(SearchService searchService) {
        this.searchService = searchService;
    }

    /**
     * GET /api/v1/search?q=&limit=3&type=all — {@code {games, users, events}}, up to {@code limit}
     * (max 20) each. {@code type} = {@code all} | {@code games} | {@code users} | {@code events}
     * narrows the search to one category (the other lists come back empty).
     */
    @GetMapping("/api/v1/search")
    public ResponseEntity<SearchResponse> search(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(defaultValue = "") String q,
            @RequestParam(defaultValue = "3") int limit,
            @RequestParam(defaultValue = "all") String type) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(searchService.search(userId, q, limit, scope(type)));
    }

    private static SearchService.Scope scope(String type) {
        try {
            return SearchService.Scope.valueOf(type.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException e) {
            throw ApiException.badRequest("INVALID_SEARCH_TYPE", "type must be all, games, users or events");
        }
    }
}
