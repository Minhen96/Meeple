import 'package:meeple_hearth/features/notifications/domain/notification_model.dart';
import 'package:meeple_hearth/l10n/gen/app_localizations.dart';

/// Text of a notification. The backend localises `title`/`body` by the
/// user's `preferredLanguage`, so those win; legacy payloads without text are
/// rendered client-side from the type and data.
String notificationText(AppLocalizations l10n, AppNotification n) {
  final server = [n.title, n.body]
      .whereType<String>()
      .where((s) => s.trim().isNotEmpty)
      .toList();
  if (server.isNotEmpty) return server.join(' — ');
  return notificationFallbackText(l10n, n);
}

/// Client-side text built from the type and data (event title, game name,
/// count), used when the server sent no title/body.
String notificationFallbackText(AppLocalizations l10n, AppNotification n) {
  final actor = n.actor?.deleted ?? false
      ? l10n.commonDeletedUser
      : n.actor?.displayName ?? l10n.notificationSomeone;
  final event = (n.data['eventTitle'] as String?) ?? l10n.notificationAnEvent;
  final game = (n.data['gameName'] as String?) ?? l10n.notificationAGame;
  final count = (n.data['count'] as num?)?.toInt() ?? 0;
  return switch (n.type) {
    'EVENT_INVITE' => l10n.notifEventInvite(actor, event),
    'EVENT_RSVP' => l10n.notifEventRsvp(actor, event),
    'EVENT_LEAVE' => l10n.notifEventLeave(actor, event),
    'EVENT_KICKED' => l10n.notifEventKicked(event),
    'EVENT_CANCELLED' => l10n.notifEventCancelled(event),
    'EVENT_UPDATED' => l10n.notifEventUpdated(event),
    'EVENT_REMINDER' => l10n.notifEventReminder(event),
    'EVENT_COMPLETED' => l10n.notifEventCompleted(event),
    'MATCH_FOUND' => l10n.notifMatchFound(game),
    'MATCH_ACCEPTED' => l10n.notifMatchAccepted(actor, game),
    'POST_LIKE' => l10n.notifPostLike(actor),
    'POST_COMMENT' => l10n.notifPostComment(actor),
    'COMMENT_MENTION' => l10n.notifCommentMention(actor),
    'POST_TAG' => l10n.notifPostTag(actor),
    'FRIEND_REQUEST' => l10n.notifFriendRequest(actor),
    'FRIEND_ACCEPTED' => l10n.notifFriendAccepted(actor),
    'RULE_NOTE_APPROVED' => l10n.notifRuleNoteApproved(game),
    'RULE_NOTE_REJECTED' => l10n.notifRuleNoteRejected(game),
    'RULEBOOK_APPROVED' => l10n.notifRulebookApproved(game),
    'RULEBOOK_REJECTED' => l10n.notifRulebookRejected(game),
    'RULEBOOK_UNDER_REVIEW' => l10n.notifRulebookUnderReview(game),
    'BGG_IMPORT_COMPLETED' => l10n.notifBggImportCompleted(count),
    _ => n.type,
  };
}

/// Label of a notification type on the preferences screen.
String notificationTypeLabel(AppLocalizations l10n, String type) =>
    switch (type) {
      'EVENT_INVITE' => l10n.prefEventInvite,
      'EVENT_RSVP' => l10n.prefEventRsvp,
      'EVENT_LEAVE' => l10n.prefEventLeave,
      'EVENT_KICKED' => l10n.prefEventKicked,
      'EVENT_CANCELLED' => l10n.prefEventCancelled,
      'EVENT_UPDATED' => l10n.prefEventUpdated,
      'EVENT_REMINDER' => l10n.prefEventReminder,
      'EVENT_COMPLETED' => l10n.prefEventCompleted,
      'MATCH_FOUND' => l10n.prefMatchFound,
      'MATCH_ACCEPTED' => l10n.prefMatchAccepted,
      'POST_LIKE' => l10n.prefPostLike,
      'POST_COMMENT' => l10n.prefPostComment,
      'COMMENT_MENTION' => l10n.prefCommentMention,
      'POST_TAG' => l10n.prefPostTag,
      'FRIEND_REQUEST' => l10n.prefFriendRequest,
      'FRIEND_ACCEPTED' => l10n.prefFriendAccepted,
      'RULE_NOTE_APPROVED' => l10n.prefRuleNoteApproved,
      'RULE_NOTE_REJECTED' => l10n.prefRuleNoteRejected,
      'RULEBOOK_APPROVED' => l10n.prefRulebookApproved,
      'RULEBOOK_REJECTED' => l10n.prefRulebookRejected,
      'RULEBOOK_UNDER_REVIEW' => l10n.prefRulebookUnderReview,
      'BGG_IMPORT_COMPLETED' => l10n.prefBggImportCompleted,
      _ => type,
    };
