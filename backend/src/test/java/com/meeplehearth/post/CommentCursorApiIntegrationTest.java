package com.meeplehearth.post;

import com.fasterxml.jackson.databind.JsonNode;
import com.meeplehearth.support.social.ApiIntegrationTestBase;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** {@code GET /posts/{id}/comments}: cursor pages (oldest first), with the legacy page shape kept. */
class CommentCursorApiIntegrationTest extends ApiIntegrationTestBase {

    private UUID post(UUID author) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO posts (id, author_id) VALUES (?, ?)", id, author);
        return id;
    }

    /** Five comments; the last two share a timestamp so the id tie-break is exercised. */
    private List<UUID> comments(UUID postId, UUID author) {
        Instant t0 = Instant.parse("2026-01-01T10:00:00Z");
        List<UUID> ids = new ArrayList<>();
        for (int i = 0; i < 5; i++) {
            UUID id = UUID.randomUUID();
            Instant at = t0.plusSeconds(Math.min(i, 3) * 60L);
            jdbc.update("INSERT INTO post_comments (id, post_id, author_id, body, created_at) VALUES (?, ?, ?, ?, ?)",
                    id, postId, author, "c" + i, ts(at));
            ids.add(id);
        }
        // Expected order: created_at, then id
        List<UUID> tied = new ArrayList<>(ids.subList(3, 5));
        tied.sort((a, b) -> string("SELECT CASE WHEN ?::uuid < ?::uuid THEN 'lt' ELSE 'gt' END", a.toString(),
                b.toString()).equals("lt") ? -1 : 1);
        List<UUID> ordered = new ArrayList<>(ids.subList(0, 3));
        ordered.addAll(tied);
        return ordered;
    }

    private static List<String> ids(JsonNode items) {
        List<String> out = new ArrayList<>();
        items.forEach(n -> out.add(n.get("id").asText()));
        return out;
    }

    @Test
    void walksAllCommentsWithTheCursor() throws Exception {
        UUID author = user();
        UUID viewer = user();
        UUID postId = post(author);
        List<UUID> expected = comments(postId, viewer);

        List<String> seen = new ArrayList<>();
        String cursor = null;
        int pages = 0;
        do {
            var request = get("/api/v1/posts/{id}/comments", postId).param("limit", "2").with(as(author));
            if (cursor != null) {
                request = request.param("cursor", cursor);
            }
            JsonNode page = json(mvc.perform(request).andExpect(status().isOk()).andReturn()).get("data");
            seen.addAll(ids(page.get("items")));
            cursor = page.get("nextCursor").isNull() ? null : page.get("nextCursor").asText();
            assertThat(page.get("hasMore").asBoolean()).isEqualTo(cursor != null);
            pages++;
        } while (cursor != null);

        assertThat(pages).isEqualTo(3);
        assertThat(seen).containsExactlyElementsOf(expected.stream().map(UUID::toString).toList());
        assertThat(json(mvc.perform(get("/api/v1/posts/{id}/comments", postId).with(as(author)))
                .andReturn()).get("data").get("items").get(0).get("author").get("username").asText()).startsWith("it_");
    }

    @Test
    void legacyPageParametersKeepTheOldShape() throws Exception {
        UUID author = user();
        UUID postId = post(author);
        comments(postId, author);

        mvc.perform(get("/api/v1/posts/{id}/comments", postId).param("page", "1").param("size", "2").with(as(author)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(2))
                .andExpect(jsonPath("$.meta.page").value(2))
                .andExpect(jsonPath("$.meta.total").value(5))
                .andExpect(jsonPath("$.meta.hasMore").value(true));
        // `size` is honoured by the cursor form too (older mobile builds send it)
        mvc.perform(get("/api/v1/posts/{id}/comments", postId).param("size", "4").with(as(author)))
                .andExpect(jsonPath("$.data.items.length()").value(4));
    }

    @Test
    void rejectsABadCursorAndHiddenPosts() throws Exception {
        UUID author = user();
        UUID blocked = user();
        UUID postId = post(author);
        mvc.perform(get("/api/v1/posts/{id}/comments", postId).param("cursor", "%%%").with(as(author)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_CURSOR"));
        block(author, blocked);
        mvc.perform(get("/api/v1/posts/{id}/comments", postId).with(as(blocked)))
                .andExpect(status().isNotFound());
        // A bare ISO instant is accepted as a cursor
        mvc.perform(get("/api/v1/posts/{id}/comments", postId).param("cursor", "2026-01-01T00:00:00Z").with(as(author)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items.length()").value(0));
    }
}
