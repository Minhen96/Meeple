// Environment-aware API constants using dart-define.
//
// Run with:
//   flutter run --dart-define=ENVIRONMENT=production
//   flutter run --dart-define=ENVIRONMENT=staging
//   flutter run  (defaults to development — points to Android emulator localhost)
//   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080  (override)

/// All API endpoint paths and configuration constants.
abstract final class ApiConstants {
  static const _env = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );
  static const _baseOverride = String.fromEnvironment('API_BASE_URL');

  static const String baseUrl = _baseOverride != ''
      ? _baseOverride
      : _env == 'production'
          ? 'https://api.meeple-hearth.com'
          : _env == 'staging'
              ? 'https://staging-api.meeple-hearth.com'
              : 'http://10.0.2.2:8080'; // Android emulator localhost

  static String get wsUrl => _baseOverride != ''
      ? '${_baseOverride.replaceFirst('http', 'ws')}/ws'
      : _env == 'production'
          ? 'wss://api.meeple-hearth.com/ws'
          : _env == 'staging'
              ? 'wss://staging-api.meeple-hearth.com/ws'
              : 'ws://10.0.2.2:8080/ws';

  static const String cdnUrl = 'https://cdn.meeple-hearth.com';

  static const String v1 = '/api/v1';

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String login = '$v1/auth/login';
  static const String register = '$v1/auth/register';
  static const String logout = '$v1/auth/logout';
  static const String refresh = '$v1/auth/refresh';
  static const String forgotPassword = '$v1/auth/forgot-password';
  static const String resetPassword = '$v1/auth/reset-password';
  static const String verifyEmail = '$v1/auth/verify-email';
  static const String resendVerification = '$v1/auth/resend-verification';
  static const String googleLogin = '$v1/auth/google';
  static const String reactivate = '$v1/auth/reactivate';
  static const String sessions = '$v1/auth/sessions';
  static const String checkUsername = '$v1/auth/check-username';
  static const String checkEmail = '$v1/auth/check-email';

  // ── Users ─────────────────────────────────────────────────────────────────
  static const String me = '$v1/users/me';
  static const String users = '$v1/users';
  static const String fcmTokens = '$v1/users/me/fcm-tokens';

  // ── Social ────────────────────────────────────────────────────────────────
  static const String friends = '$v1/friends';
  static const String friendRequests = '$v1/friend-requests';
  static const String reports = '$v1/reports';
  static const String search = '$v1/search';

  // ── Games ─────────────────────────────────────────────────────────────────
  static const String games = '$v1/games';
  static const String myCollection = '$v1/users/me/games';
  static const String aiRules = '$v1/ai/rules';

  // ── Feed / Posts ──────────────────────────────────────────────────────────
  static const String feed = '$v1/feed';
  static const String posts = '$v1/posts';

  // ── Events / Matching ─────────────────────────────────────────────────────
  static const String events = '$v1/events';
  static const String matches = '$v1/matches';

  // ── Notifications ─────────────────────────────────────────────────────────
  static const String notifications = '$v1/notifications';

  // ── Uploads ────────────────────────────────────────────────────────────────
  /// Body `{contentType, size}` → `{uploadUrl, key, publicUrl}`.
  static const String uploadPresign = '$v1/upload/presign';

  /// Must match the backend's `storage.max-upload-bytes` (10 MB).
  static const int maxUploadBytes = 10 * 1024 * 1024;

  // ── WebSocket (STOMP) ──────────────────────────────────────────────────────
  /// Per-user notification queue; the broker resolves it to the session user.
  static const String wsNotificationsQueue = '/user/queue/notifications';

  // ── Timeouts ──────────────────────────────────────────────────────────────
  static const int connectTimeoutMs = 15000;
  static const int receiveTimeoutMs = 30000;

  // Private constructor.
  const ApiConstants._();
}
