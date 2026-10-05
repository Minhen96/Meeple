import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeple_hearth/app.dart';
import 'package:meeple_hearth/core/network/auth_session.dart';
import 'package:meeple_hearth/core/network/connectivity_service.dart';
import 'package:meeple_hearth/core/network/dio_client.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/core/security/biometric_service.dart';
import 'package:meeple_hearth/features/auth/data/google_auth_client.dart';
import 'package:meeple_hearth/features/notifications/data/realtime_service.dart';

import 'fake_api.dart';
import 'fixtures.dart';

class FakeGoogle implements GoogleAuthClient {
  FakeGoogle({this.available = false, this.token});

  final bool available;
  final String? token;
  int signOuts = 0;

  @override
  bool get isAvailable => available;

  @override
  Future<String?> signIn() async => token;

  @override
  Future<void> signOut() async => signOuts++;
}

class FakeAuthenticator implements DeviceAuthenticator {
  FakeAuthenticator({this.available = true, this.result = true});

  final bool available;
  final bool result;

  @override
  Future<bool> authenticate(String reason) async => result;

  @override
  Future<bool> isAvailable() async => available;
}

/// Registers the endpoints every signed-in screen touches.
void stubDefaults(FakeApi api, {Map<String, dynamic>? me}) {
  api
    ..get('/api/v1/users/me', me ?? userJson())
    ..get('/api/v1/feed', cursor([
      {'kind': 'post', 'createdAt': '2026-09-01T10:00:00Z', 'post': postJson()},
      {
        'kind': 'activity',
        'createdAt': '2026-09-01T09:00:00Z',
        'activity': {
          'id': 'a1',
          'type': 'collection_add',
          'user': summaryJson('f1', 'Fred'),
          'data': {'gameId': 'g1', 'gameName': 'Catan'},
        },
      },
    ]))
    ..get('/api/v1/notifications/unread-count', {'count': 2})
    ..get('/api/v1/matches/suggestions', [matchGroupJson()])
    ..get('/api/v1/events', [eventJson()])
    ..get('/api/v1/users/me/games', [
      userGameJson(),
      userGameJson(gameId: 'g2', title: 'Azul', owned: false, wishlisted: true),
      userGameJson(gameId: 'g3', title: 'Wingspan', favorited: true),
    ])
    ..get('/api/v1/users/me/stats', {
      'gamesOwned': 12,
      'sessions': 30,
      'friends': 4,
      'mostPlayedGame': {'gameId': 'g1', 'title': 'Catan', 'playCount': 9},
      'favoriteCategory': 'Strategy',
      'mostPlayedWith': null,
      'totalPlayMinutes': 1200,
    })
    ..get('/api/v1/friends', {
      'data': [summaryJson('f1', 'Fred'), summaryJson('f2', 'Tina')],
      'meta': {'page': 1, 'limit': 30, 'total': 2, 'hasMore': false},
    });
}

/// Signs the fake device in (session in secure storage).
void signIn() {
  FlutterSecureStorage.setMockInitialValues({
    'auth_session': jsonEncode({
      'accessToken': 'a',
      'refreshToken': 'r',
      'userId': 'me',
    }),
  });
}

void signOut() => FlutterSecureStorage.setMockInitialValues({});

List<Override> baseOverrides(
  FakeApi api, {
  FakeGoogle? google,
  bool online = true,
  DeviceAuthenticator? authenticator,
}) =>
    [
      dioProvider.overrideWithValue(api.dio()),
      connectivityStreamProvider.overrideWith((ref) => Stream.value(online)),
      // Never opens a socket in tests.
      realtimeServiceProvider.overrideWith(
        (ref) => RealtimeService(ref.read(authSessionManagerProvider)),
      ),
      googleAuthClientProvider.overrideWithValue(google ?? FakeGoogle()),
      deviceAuthenticatorProvider
          .overrideWithValue(authenticator ?? FakeAuthenticator()),
    ];

/// Pumps a few frames (shimmer/progress animations never settle).
Future<void> settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Starts the full app at [location]. Returns the container for reads.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  required FakeApi api,
  String location = '/',
  bool signedIn = true,
  List<Override> overrides = const [],
  FakeGoogle? google,
  bool online = true,
}) async {
  signedIn ? signIn() : signOut();
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      ...baseOverrides(api, google: google, online: online),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MeepleApp()),
  );
  await settle(tester, 5);
  if (location != '/') {
    container.read(appRouterProvider).go(location);
  }
  await settle(tester);
  return container;
}

/// Pushes [location] on top of the current stack.
Future<void> push(
  WidgetTester tester,
  ProviderContainer container,
  String location,
) async {
  container.read(appRouterProvider).push(location);
  await settle(tester);
}
