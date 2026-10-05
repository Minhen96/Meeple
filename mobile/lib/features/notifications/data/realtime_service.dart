import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/api_constants.dart';
import 'package:meeple_hearth/core/network/auth_session.dart';
import 'package:meeple_hearth/core/utils/app_logger.dart';
import 'package:meeple_hearth/features/auth/domain/user_model.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

/// Keeps the STOMP connection in step with the auth state: connected while a
/// user is signed in, closed on logout.
final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final service = RealtimeService(ref.read(authSessionManagerProvider));
  ref
    ..listen<AsyncValue<User?>>(
      authNotifierProvider,
      (_, next) {
        if (next.isLoading) return;
        if (next.valueOrNull != null) {
          service.start();
        } else {
          service.stop();
        }
      },
      fireImmediately: true,
    )
    ..onDispose(service.dispose);
  return service;
});

/// Realtime notifications over STOMP (`/ws`).
///
/// * CONNECT carries `Authorization: Bearer <access token>`; the backend
///   rejects unauthenticated sessions. The token is refreshed (through the
///   shared single-flight [AuthSessionManager]) before every (re)connect when
///   it is close to expiry, or unconditionally after the server rejected or
///   closed the session.
/// * Per-user events arrive on `/user/queue/notifications`.
/// * The server closes sessions whose token expired or was revoked; the
///   service reconnects with exponential backoff and stops for good once the
///   refresh token is rejected (the user is logged out) or [stop] is called.
final class RealtimeService {
  RealtimeService(this._session);

  static const _maxBackoff = Duration(seconds: 30);

  final AuthSessionManager _session;
  final _notifications = StreamController<Map<String, dynamic>>.broadcast();
  final _random = Random();

  StompClient? _client;
  Timer? _retryTimer;
  bool _running = false;
  bool _forceRefresh = false;
  int _attempt = 0;
  int _generation = 0;

  /// Notification payloads (`NotificationResponse` JSON).
  Stream<Map<String, dynamic>> get notifications => _notifications.stream;

  bool get isConnected => _client?.connected ?? false;

  void start() {
    if (_running) return;
    _running = true;
    _attempt = 0;
    _forceRefresh = false;
    unawaited(_connect());
  }

  void stop() {
    _running = false;
    _generation++;
    _retryTimer?.cancel();
    _retryTimer = null;
    _client?.deactivate();
    _client = null;
  }

  void dispose() {
    stop();
    _notifications.close();
  }

  Future<void> _connect() async {
    final generation = ++_generation;

    final String? token;
    try {
      if (_forceRefresh) {
        final stale = await _session.currentAccessToken();
        token = stale == null
            ? null
            : await _session.refresh(staleAccessToken: stale);
      } else {
        token = await _session.freshAccessToken();
      }
    } on SessionExpiredException {
      stop();
      return;
    } catch (_) {
      // Network trouble while refreshing — keep the session and retry later.
      if (generation == _generation) _scheduleRetry();
      return;
    }
    if (!_running || generation != _generation) return;
    if (token == null) {
      stop(); // logged out
      return;
    }
    _forceRefresh = false;

    late final StompClient client;
    client = StompClient(
      config: StompConfig(
        url: ApiConstants.wsUrl,
        // Reconnection is driven here so each attempt gets a fresh token.
        reconnectDelay: Duration.zero,
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        onConnect: (_) {
          if (generation != _generation) return;
          _attempt = 0;
          client.subscribe(
            destination: ApiConstants.wsNotificationsQueue,
            callback: _onNotification,
          );
        },
        onStompError: (_) {
          // Rejected CONNECT or a server-side close (expired/revoked token):
          // the next attempt must present a newly refreshed token.
          _forceRefresh = true;
          _onAttemptEnded(generation);
        },
        onWebSocketError: (_) => _onAttemptEnded(generation),
        onWebSocketDone: () => _onAttemptEnded(generation),
      ),
    );
    _client = client;
    client.activate();
  }

  void _onNotification(StompFrame frame) {
    final body = frame.body;
    if (body == null || _notifications.isClosed) return;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) _notifications.add(decoded);
    } on FormatException {
      AppLogger.warning('Ignoring malformed notification frame');
    }
  }

  void _onAttemptEnded(int generation) {
    if (!_running || generation != _generation) return;
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (!_running || (_retryTimer?.isActive ?? false)) return;
    final exp = min(_attempt, 5);
    _attempt++;
    final base = Duration(seconds: 1 << exp);
    final delay = (base > _maxBackoff ? _maxBackoff : base) +
        Duration(milliseconds: _random.nextInt(1000));
    _retryTimer = Timer(delay, () {
      _client?.deactivate();
      _client = null;
      if (_running) unawaited(_connect());
    });
  }
}
