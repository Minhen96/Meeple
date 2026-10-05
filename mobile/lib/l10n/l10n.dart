import 'package:flutter/widgets.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/l10n/gen/app_localizations.dart';

export 'package:meeple_hearth/l10n/gen/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// The user-facing, localised message for [error].
///
/// Known error codes and exception types map to translated strings; other
/// API errors fall back to the server's (English) message.
String localizedError(AppLocalizations l10n, Object error) {
  if (error is! ApiException) return l10n.errorGeneric;
  final byCode = switch (error.code) {
    'OFFLINE' => l10n.errorOffline,
    'CANNOT_INVITE_SELF' => l10n.errorCannotInviteSelf,
    'BGG_IMPORT_IN_PROGRESS' => l10n.errorBggImportInProgress,
    'FILE_TOO_LARGE' => l10n.errorFileTooLarge,
    'UNSUPPORTED_CONTENT_TYPE' => l10n.errorUnsupportedImage,
    'EMAIL_NOT_VERIFIED' => l10n.errorEmailNotVerified,
    'EDIT_WINDOW_EXPIRED' => l10n.errorEditWindowExpired,
    'EVENT_CANCELLED' => l10n.errorEventCancelled,
    'EVENT_COMPLETED' => l10n.errorEventCompleted,
    'EVENT_FULL' => l10n.errorEventFull,
    'NOT_HOST' => l10n.errorNotHost,
    'NOT_FRIENDS' => l10n.errorNotFriends,
    'REQUEST_COOLDOWN' => l10n.errorRequestCooldown,
    'PENDING_LIMIT' => l10n.errorPendingLimit,
    'REPORT_LIMIT_EXCEEDED' => l10n.errorReportLimit,
    'BGG_USER_NOT_FOUND' => l10n.errorBggUserNotFound,
    'BGG_API_UNAVAILABLE' || 'BGG_UNAVAILABLE' => l10n.errorBggUnavailable,
    'USERNAME_CHANGE_TOO_SOON' => l10n.errorUsernameTooSoon,
    'USERNAME_TAKEN' => l10n.errorUsernameTaken,
    'EMAIL_TAKEN' => l10n.errorEmailTaken,
    'ACCOUNT_DELETED' => l10n.errorAccountDeleted,
    'GOOGLE_EMAIL_NOT_VERIFIED' => l10n.errorGoogleEmailNotVerified,
    'GOOGLE_ACCOUNT_CONFLICT' => l10n.errorGoogleAccountConflict,
    'INVALID_GOOGLE_TOKEN' => l10n.errorGoogleFailed,
    'RATE_LIMIT_EXCEEDED' => l10n.errorRateLimit,
    'AI_RATE_LIMIT' || 'AI_DAILY_LIMIT' => l10n.aiRateLimit,
    'INVALID_PASSWORD' || 'INVALID_CREDENTIALS' => l10n.errorInvalidCredentials,
    _ => null,
  };
  if (byCode != null) return byCode;
  return switch (error) {
    NetworkException() => l10n.errorNetwork,
    TimeoutException() => l10n.errorTimeout,
    OfflineException() => l10n.errorOffline,
    UnauthorizedException(:final message)
        when message == UnauthorizedException.defaultMessage =>
      l10n.errorSessionExpired,
    ForbiddenException() => l10n.errorForbidden,
    NotFoundException() => l10n.errorNotFound,
    RateLimitException() => l10n.errorRateLimit,
    ServiceUnavailableException() => l10n.errorServiceUnavailable,
    ServerException() => l10n.errorServer,
    _ => error.message,
  };
}
