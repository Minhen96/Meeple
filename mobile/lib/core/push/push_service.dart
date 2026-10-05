import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:meeple_hearth/core/push/push_messaging.dart';
import 'package:meeple_hearth/core/storage/secure_storage.dart';
import 'package:meeple_hearth/core/utils/app_logger.dart';
import 'package:meeple_hearth/features/notifications/data/notification_repository.dart';

/// FCM integration (docs/MOBILE_FLUTTER.md §8).
///
/// * The system permission is only requested after the in-app pre-prompt
///   ([requestPermission]); [shouldShowPrePrompt] tells the UI when to show it.
/// * While signed in with permission granted, the device token is registered
///   with `POST /users/me/fcm-tokens` and re-registered on refresh.
/// * Foreground messages are shown as local notifications on the matching
///   Android channel; taps (local or system) emit their `data.path` on
///   [navigationRequests].
/// * [stop] (logout) deletes the token from the backend.
///
/// When Firebase is not configured [messaging] is null and every method is a
/// no-op.
final class PushService {
  PushService({
    required PushMessaging? messaging,
    required LocalNotifications? local,
    required NotificationRepository repository,
    required SecureStorage storage,
    String? platform,
  })  : _messaging = messaging,
        _local = local,
        _repository = repository,
        _storage = storage,
        _platform = platform ??
            (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');

  static const _prePromptKey = 'push_preprompt_done';

  final PushMessaging? _messaging;
  final LocalNotifications? _local;
  final NotificationRepository _repository;
  final SecureStorage _storage;
  final String _platform;

  final _navigation = StreamController<String>.broadcast();
  final _foreground = StreamController<PushMessage>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  bool _localReady = false;
  bool _running = false;
  String? _registeredToken;
  int _nextId = 0;

  bool get isEnabled => _messaging != null;

  /// Deep-link paths to open (notification taps).
  Stream<String> get navigationRequests => _navigation.stream;

  /// Foreground messages (to refresh unread counts).
  Stream<PushMessage> get foregroundMessages => _foreground.stream;

  /// True when push is available, the user was never asked, and the OS has
  /// not decided yet.
  Future<bool> shouldShowPrePrompt() async {
    final messaging = _messaging;
    if (messaging == null) return false;
    if (await _storage.readPref(_prePromptKey) != null) return false;
    try {
      return await messaging.getPermission() == PushPermission.notDetermined;
    } catch (_) {
      return false;
    }
  }

  /// "Not now" on the pre-prompt: never ask again automatically.
  Future<void> dismissPrePrompt() => _storage.writePref(_prePromptKey, 'no');

  /// "Allow" on the pre-prompt: asks the OS, then registers when granted.
  Future<bool> requestPermission() async {
    final messaging = _messaging;
    if (messaging == null) return false;
    await _storage.writePref(_prePromptKey, 'asked');
    final permission = await messaging.requestPermission();
    if (permission != PushPermission.granted) return false;
    if (_running) await _registerCurrentToken();
    return true;
  }

  /// Signed in: listen for messages and register the token if permitted.
  Future<void> start() async {
    final messaging = _messaging;
    if (messaging == null || _running) return;
    _running = true;
    try {
      await _ensureLocal();
      _subscriptions
        ..add(messaging.onMessage.listen(_onForegroundMessage))
        ..add(messaging.onMessageOpenedApp.listen(_onOpened))
        ..add(messaging.onTokenRefresh.listen(_register));

      final initial = await messaging.getInitialMessage();
      if (initial != null) _onOpened(initial);
      final launch = await _local?.launchPayload();
      if (launch != null) _navigate(launch);

      if (await messaging.getPermission() == PushPermission.granted) {
        await _registerCurrentToken();
      }
    } catch (e) {
      AppLogger.warning('Push start failed', error: e);
    }
  }

  /// Logout: unregister this device's token (best effort) and stop.
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    final token = _registeredToken ?? await _storage.getFcmToken();
    _registeredToken = null;
    if (token == null) return;
    try {
      await _repository.unregisterFcmToken(token);
    } catch (e) {
      AppLogger.warning('FCM token unregister failed', error: e);
    }
    await _storage.deleteFcmToken();
  }

  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _navigation.close();
    await _foreground.close();
  }

  Future<void> _ensureLocal() async {
    if (_localReady || _local == null) return;
    await _local.initialize((payload) {
      if (payload != null) _navigate(payload);
    });
    _localReady = true;
  }

  Future<void> _registerCurrentToken() async {
    final token = await _messaging?.getToken();
    if (token != null) await _register(token);
  }

  Future<void> _register(String token) async {
    if (!_running) return;
    try {
      await _repository.registerFcmToken(token: token, platform: _platform);
      _registeredToken = token;
      await _storage.saveFcmToken(token);
    } catch (e) {
      AppLogger.warning('FCM token registration failed', error: e);
    }
  }

  void _onForegroundMessage(PushMessage message) {
    if (!_foreground.isClosed) _foreground.add(message);
    final title = message.title;
    final local = _local;
    if (title == null || local == null) return;
    unawaited(
      local.show(
        id: _nextId++,
        title: title,
        body: message.body ?? '',
        channelId: PushChannels.forType(message.type),
        payload: message.path,
      ),
    );
  }

  void _onOpened(PushMessage message) {
    final path = message.path;
    if (path != null) _navigate(path);
  }

  void _navigate(String path) {
    if (path.startsWith('/') && !_navigation.isClosed) _navigation.add(path);
  }
}
