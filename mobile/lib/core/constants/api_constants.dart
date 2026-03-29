// Environment-aware API constants using dart-define.
//
// Run with:
//   flutter run --dart-define=ENVIRONMENT=production
//   flutter run --dart-define=ENVIRONMENT=staging
//   flutter run  (defaults to development — points to Android emulator localhost)
//
// In CI/CD, set ENVIRONMENT via your build configuration.

/// All API endpoint paths and configuration constants.
abstract final class ApiConstants {
  static const _env = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  static const String baseUrl = _env == 'production'
      ? 'https://api.meeple-hearth.com'
      : _env == 'staging'
          ? 'https://staging-api.meeple-hearth.com'
          : 'http://10.0.2.2:8080'; // Android emulator localhost

  static const String wsUrl = _env == 'production'
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

  // ── Users ─────────────────────────────────────────────────────────────────
  static const String me = '$v1/users/me';
  static const String users = '$v1/users';

  // ── Games ─────────────────────────────────────────────────────────────────
  static const String games = '$v1/games';
  static const String myCollection = '$v1/users/me/games';

  // ── Feed ──────────────────────────────────────────────────────────────────
  static const String feed = '$v1/feed';

  // ── Posts ─────────────────────────────────────────────────────────────────
  static const String posts = '$v1/posts';

  // ── Events ────────────────────────────────────────────────────────────────
  static const String events = '$v1/events';

  // ── BGG ───────────────────────────────────────────────────────────────────
  static const String bgg = '$v1/users/me/bgg';

  // ── FCM ───────────────────────────────────────────────────────────────────
  static const String fcmToken = '$v1/users/me/fcm-token';

  // ── Timeouts ──────────────────────────────────────────────────────────────
  static const int connectTimeoutMs = 15000;
  static const int receiveTimeoutMs = 30000;

  // Private constructor.
  const ApiConstants._();
}
