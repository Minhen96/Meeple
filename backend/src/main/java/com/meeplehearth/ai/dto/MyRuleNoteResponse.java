package com.meeplehearth.ai.dto;

import com.meeplehearth.ai.entity.GameRuleNote;

public record MyRuleNoteResponse(
        String id,
        String content,
        String status,
        String rejectReason,
        String updatedAt
) {
    public static MyRuleNoteResponse from(GameRuleNote note) {
        return new MyRuleNoteResponse(
                note.getId().toString(),
                note.getContent(),
                note.getStatus(),
                note.getRejectReason(),
                note.getUpdatedAt().toString()
        );
    }
}
