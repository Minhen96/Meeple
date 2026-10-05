/// Build-time configuration passed with `--dart-define`.
///
/// Every value is optional: a feature whose key is empty is disabled
/// gracefully (see docs/MOBILE_FLUTTER.md §17 for the full list).
abstract final class AppConfig {
  /// `development` | `staging` | `production`.
  static const environment =
      String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');

  /// Sentry crash reporting.
  static const sentryDsn = String.fromEnvironment('SENTRY_DSN');

  /// PostHog product analytics.
  static const posthogApiKey = String.fromEnvironment('POSTHOG_API_KEY');
  static const posthogHost = String.fromEnvironment(
    'POSTHOG_HOST',
    defaultValue: 'https://eu.i.posthog.com',
  );

  /// Google Sign-In. [googleServerClientId] is the **web** OAuth client id
  /// the backend verifies ID tokens against (`GOOGLE_CLIENT_ID` on the
  /// server); [googleIosClientId] is the iOS OAuth client id.
  static const googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  static const googleIosClientId =
      String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  static bool get googleSignInEnabled => googleServerClientId.isNotEmpty;
  static bool get analyticsEnabled => posthogApiKey.isNotEmpty;

  /// Public web origin used for share links and App/Universal Links.
  static const webOrigin = String.fromEnvironment(
    'WEB_ORIGIN',
    defaultValue: 'https://meeple-hearth.com',
  );
}
