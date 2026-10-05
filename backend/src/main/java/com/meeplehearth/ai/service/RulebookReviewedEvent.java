package com.meeplehearth.ai.service;

import com.meeplehearth.notification.entity.Notification.NotificationType;

import java.util.UUID;

/**
 * A user-uploaded rulebook changed review state (AI_PLAN feature 3). Published inside the review
 * transaction; {@link RulebookNotificationListener} notifies the uploader after commit.
 *
 * @param uploaderId the user who uploaded the PDF
 * @param type       RULEBOOK_APPROVED | RULEBOOK_REJECTED | RULEBOOK_UNDER_REVIEW
 * @param gameId     the game, so the notification deep-links to /library/{gameId}
 * @param reviewerId the admin who acted, or null (local dev with open admin endpoints)
 */
public record RulebookReviewedEvent(UUID uploaderId, NotificationType type, UUID gameId, UUID reviewerId) {
}
