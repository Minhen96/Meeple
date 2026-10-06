package com.meeplehearth.post;

import com.fasterxml.jackson.databind.JsonNode;
import com.meeplehearth.support.social.ApiIntegrationTestBase;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Tagged users blocked with the viewer (either way) are left out of every post response. */
class TaggedUsersBlockFilterIntegrationTest extends ApiIntegrationTestBase {

    private UUID post(UUID author, UUID... tagged) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO posts (id, author_id, caption) VALUES (?, ?, 'Game night')", id, author);
        for (UUID user : tagged) {
            jdbc.update("INSERT INTO post_tags (id, post_id, tagged_user_id) VALUES (?, ?, ?)",
                    UUID.randomUUID(), id, user);
        }
        return id;
    }

    private static List<String> taggedIds(JsonNode post) {
        List<String> ids = new ArrayList<>();
        post.get("taggedUsers").forEach(t -> ids.add(t.get("id").asText()));
        return ids;
    }

    private JsonNode findPost(JsonNode page, UUID postId) {
        JsonNode items = page.has("items") ? page.get("items") : page;
        for (JsonNode item : items) {
            JsonNode post = item.has("post") ? item.get("post") : item;
            if (post.has("id") && post.get("id").asText().equals(postId.toString())) {
                return post;
            }
        }
        throw new AssertionError("post " + postId + " not in " + items);
    }

    @Test
    void blockedTaggedUsersAreHiddenFromTheViewer() throws Exception {
        UUID author = user();
        UUID viewer = user();
        UUID friendTag = user();
        UUID blockedByViewer = user();
        UUID blockingViewer = user();
        friends(author, viewer);
        block(viewer, blockedByViewer);
        block(blockingViewer, viewer);
        UUID postId = post(author, friendTag, blockedByViewer, blockingViewer);

        JsonNode detail = json(mvc.perform(get("/api/v1/posts/" + postId).with(as(viewer)))
                .andExpect(status().isOk()).andReturn()).get("data");
        assertThat(taggedIds(detail)).containsExactly(friendTag.toString());

        JsonNode authorPosts = json(mvc.perform(get("/api/v1/users/" + author + "/posts").with(as(viewer)))
                .andExpect(status().isOk()).andReturn()).get("data");
        assertThat(taggedIds(findPost(authorPosts, postId))).containsExactly(friendTag.toString());

        JsonNode feed = json(mvc.perform(get("/api/v1/feed").with(as(viewer)))
                .andExpect(status().isOk()).andReturn()).get("data");
        assertThat(taggedIds(findPost(feed, postId))).containsExactly(friendTag.toString());

        // The author, who blocked nobody, still sees every tag
        JsonNode own = json(mvc.perform(get("/api/v1/posts/" + postId).with(as(author)))
                .andExpect(status().isOk()).andReturn()).get("data");
        assertThat(taggedIds(own)).containsExactlyInAnyOrder(
                friendTag.toString(), blockedByViewer.toString(), blockingViewer.toString());
    }
}
