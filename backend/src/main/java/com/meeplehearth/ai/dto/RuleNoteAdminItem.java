package com.meeplehearth.ai.dto;

import com.meeplehearth.ai.entity.GameRuleNote;

public record RuleNoteAdminItem(
        String id,
        String gameId,
        String gameName,
        String content,
        String submittedByUsername,
        String createdAt
) {
    public static RuleNoteAdminItem from(GameRuleNote note) {
        return new RuleNoteAdminItem(
                note.getId().toString(),
                note.getGame().getId().toString(),
                note.getGame().getNameEn(),
                note.getContent(),
                note.getUser().getUsername(),
                note.getCreatedAt().toString()
        );
    }
}
