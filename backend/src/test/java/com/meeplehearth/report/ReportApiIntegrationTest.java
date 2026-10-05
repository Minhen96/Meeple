package com.meeplehearth.report;

import com.meeplehearth.support.social.ApiIntegrationTestBase;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;

import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** POST /reports: idempotent per target, 5 per reporter per day, targets must exist. */
class ReportApiIntegrationTest extends ApiIntegrationTestBase {

    @Test
    void reportsAreStoredOncePerTargetAndLimitedToFivePerDay() throws Exception {
        UUID me = user();
        UUID author = user();
        UUID postId = UUID.randomUUID();
        jdbc.update("INSERT INTO posts (id, author_id, caption) VALUES (?, ?, 'spam')", postId, author);
        UUID commentId = UUID.randomUUID();
        jdbc.update("INSERT INTO post_comments (id, post_id, author_id, body) VALUES (?, ?, ?, 'rude')",
                commentId, postId, author);

        report(me, "user", author, "  harassment ").andExpect(status().isCreated());
        report(me, "USER", author, "again").andExpect(status().isCreated()); // already reported: still 201
        report(me, "post", postId, "spam").andExpect(status().isCreated());
        report(me, "comment", commentId, "rude").andExpect(status().isCreated());

        assertThat(count("SELECT COUNT(*) FROM reports WHERE reporter_id = ?", me)).isEqualTo(3);
        assertThat(string("SELECT reason FROM reports WHERE reporter_id = ? AND target_type = 'USER'", me))
                .isEqualTo("harassment");

        report(me, "user", user(), "x").andExpect(status().isCreated()); // 5th attempt today
        report(me, "user", user(), "x")
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("REPORT_LIMIT_EXCEEDED"));
        assertThat(count("SELECT COUNT(*) FROM reports WHERE reporter_id = ?", me)).isEqualTo(4);
    }

    @Test
    void invalidReportsAreRejectedWithoutUsingTheQuota() throws Exception {
        UUID me = user();
        UUID deletedUser = user();
        softDeleteUser(deletedUser);

        report(me, "event", UUID.randomUUID(), "x")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
        report(me, "user", me, "x")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_TARGET"));
        report(me, "post", UUID.randomUUID(), "x")
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("REPORT_TARGET_NOT_FOUND"));
        report(me, "comment", UUID.randomUUID(), "x").andExpect(status().isNotFound());
        report(me, "user", deletedUser, "x").andExpect(status().isNotFound());
        report(me, "user", user(), "")
                .andExpect(status().isBadRequest());
        report(me, "user", user(), "x".repeat(501))
                .andExpect(status().isBadRequest());

        for (int i = 0; i < 5; i++) {
            report(me, "user", user(), "ok").andExpect(status().isCreated());
        }
    }

    private ResultActions report(UUID reporter, String type, UUID target, String reason) throws Exception {
        return mvc.perform(post("/api/v1/reports").with(as(reporter))
                .contentType(MediaType.APPLICATION_JSON)
                .content(toJson(Map.of("targetType", type, "targetId", target, "reason", reason))));
    }
}
