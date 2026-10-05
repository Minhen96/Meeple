import 'package:meeple_hearth/core/config/app_config.dart';
import 'package:meeple_hearth/core/utils/app_logger.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// PostHog product analytics, initialised only when `POSTHOG_API_KEY` is
/// defined (`--dart-define=POSTHOG_API_KEY=phc_...`). Events never carry
/// PII (no emails, tokens or free text).
abstract final class AnalyticsService {
  static bool _enabled = false;

  static bool get isEnabled => _enabled;

  static Future<void> init({String apiKey = AppConfig.posthogApiKey}) async {
    if (apiKey.isEmpty) return;
    try {
      final config = PostHogConfig(apiKey)
        ..host = AppConfig.posthogHost
        ..captureApplicationLifecycleEvents = true
        ..debug = AppConfig.environment != 'production';
      await Posthog().setup(config);
      _enabled = true;
    } catch (e) {
      AppLogger.warning('PostHog init failed', error: e);
    }
  }

  static Future<void> identify(String userId) async {
    if (_enabled) await Posthog().identify(userId: userId);
  }

  static Future<void> reset() async {
    if (_enabled) await Posthog().reset();
  }

  static Future<void> capture(
    String event, [
    Map<String, Object> properties = const {},
  ]) async {
    if (_enabled) {
      await Posthog().capture(eventName: event, properties: properties);
    }
  }

  static Future<void> screen(String name) async {
    if (_enabled) await Posthog().screen(screenName: name);
  }
}
