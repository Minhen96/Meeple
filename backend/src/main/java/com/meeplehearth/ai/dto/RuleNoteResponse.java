package com.meeplehearth.ai.dto;

import com.meeplehearth.ai.entity.GameRuleNote;

public record RuleNoteResponse(
        String id,
        String content,
        String submittedByUsername,
        String createdAt
) {
    public static RuleNoteResponse from(GameRuleNote note) {
        return new RuleNoteResponse(
                note.getId().toString(),
                note.getContent(),
                note.getUser().getUsername(),
                note.getCreatedAt().toString()
        );
    }
}
