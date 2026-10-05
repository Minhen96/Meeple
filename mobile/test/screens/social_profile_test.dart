import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';
import '../helpers/harness.dart';

void main() {
  late FakeApi api;

  setUp(() {
    api = FakeApi();
    stubDefaults(api);
    api
      ..get('/api/v1/users/me/posts', cursor([postJson(authorId: 'me')]))
      ..get('/api/v1/users/f1', userJson(id: 'f1', username: 'fred', displayName: 'Fred'))
      ..get('/api/v1/users/f1/stats', {'gamesOwned': 5, 'sessions': 7, 'friends': 1})
      ..get('/api/v1/users/f1/posts', cursor([]))
      ..get('/api/v1/users/f1/games', [userGameJson()])
      ..get('/api/v1/users/f1/friend-status', {'status': 'NONE', 'requestId': null})
      ..post('/api/v1/users/f1/friend-request', {
        'id': 'fr1',
        'sender': summaryJson('me'),
        'receiver': summaryJson('f1'),
        'status': 'PENDING',
      })
      ..delete('/api/v1/users/f1/friend-request', const FakeResponse.noContent())
      ..post('/api/v1/users/f1/block', const FakeResponse.noContent());
  });

  testWidgets('own profile shows stats bento, favorites and tabs',
      (tester) async {
    await pumpApp(tester, api: api, location: '/profile');

    expect(find.text('Mia Meeple'), findsWidgets);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.textContaining('Most played: Catan'), findsOneWidget);
    expect(find.byKey(const ValueKey('post-thumb-p1')), findsOneWidget);

    await tester.tap(find.text('Tagged'));
    await settle(tester);
    expect(find.text('Tagged posts'), findsOneWidget);

    await tester.tap(find.text('Collection').last);
    await settle(tester);
    expect(find.text('See all'), findsOneWidget);
  });

  testWidgets('other profile: Add Friend → Pending → cancel', (tester) async {
    await pumpApp(tester, api: api, location: '/profile/f1');

    expect(find.text('Fred'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('add-friend-f1')));
    await settle(tester);
    expect(find.text('Pending'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pending-f1')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('confirm-sheet-confirm')));
    await settle(tester);
    expect(api.called('DELETE', '/api/v1/users/f1/friend-request'), isTrue);
    expect(find.text('Add Friend'), findsOneWidget);
  });

  testWidgets('blocking a user', (tester) async {
    await pumpApp(tester, api: api, location: '/profile/f1');

    await tester.tap(find.byKey(const Key('user-profile-menu')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('profile-block')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('confirm-sheet-confirm')));
    await settle(tester);
    expect(api.called('POST', '/api/v1/users/f1/block'), isTrue);
  });

  testWidgets('blocked profile (404) is unavailable', (tester) async {
    await pumpApp(tester, api: api, location: '/profile/blocked');
    expect(find.text("This profile isn't available."), findsOneWidget);
  });

  testWidgets('friends screen: accept a request and search people',
      (tester) async {
    api
      ..get('/api/v1/friend-requests/received', {
        'data': [
          {
            'id': 'fr9',
            'sender': summaryJson('f9', 'Nina'),
            'receiver': summaryJson('me'),
            'status': 'PENDING',
          },
        ],
        'meta': {'page': 1, 'limit': 30, 'total': 1, 'hasMore': false},
      })
      ..get('/api/v1/friend-requests/sent', {
        'data': <Object>[],
        'meta': {'page': 1, 'limit': 30, 'total': 0, 'hasMore': false},
      })
      ..post('/api/v1/friend-requests/fr9/accept', const FakeResponse.noContent())
      ..get('/api/v1/users/suggestions', {
        'data': [
          {...summaryJson('f7', 'Olly'), 'friendshipStatus': 'none'},
        ],
        'meta': {'page': 1, 'limit': 10, 'total': 1, 'hasMore': false},
      })
      ..get('/api/v1/users/f7/friend-status', {'status': 'NONE'});
    await pumpApp(tester, api: api, location: '/friends');

    expect(find.text('Tina'), findsOneWidget);

    await tester.tap(find.text('Requests'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('request-accept-fr9')));
    await settle(tester);
    expect(api.called('POST', '/api/v1/friend-requests/fr9/accept'), isTrue);

    await tester.tap(find.text('Find'));
    await settle(tester);
    expect(find.text('Olly'), findsOneWidget);
    expect(find.byKey(const ValueKey('add-friend-f7')), findsOneWidget);
  });

  testWidgets('search shows grouped results and remembers the query',
      (tester) async {
    api.get('/api/v1/search', {
      'games': [gameJson()],
      'users': [
        {...summaryJson('f1', 'Fred'), 'friendshipStatus': 'friends'},
      ],
      'events': [eventJson()],
    });
    await pumpApp(tester, api: api, location: '/search');

    await tester.enterText(find.byKey(const Key('search-input')), 'cat');
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);

    expect(find.text('Games'), findsOneWidget);
    expect(find.text('Players'), findsOneWidget);
    expect(find.text('Catan Night'), findsOneWidget);
    expect(find.byKey(const ValueKey('add-friend-f1')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('search-input')), '');
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);
    expect(find.text('Recent searches'), findsOneWidget);
    expect(find.text('cat'), findsOneWidget);
  });

  testWidgets('search falls back to games + users when /search is missing',
      (tester) async {
    api
      ..get('/api/v1/games', springPage([gameJson()]))
      ..get('/api/v1/users/search', {
        'data': <Object>[],
        'meta': {'page': 1, 'limit': 3, 'total': 0, 'hasMore': false},
      });
    await pumpApp(tester, api: api, location: '/search');

    await tester.enterText(find.byKey(const Key('search-input')), 'cat');
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);
    expect(find.text('Catan'), findsOneWidget);
  });

  testWidgets('matching: create a request and accept flow', (tester) async {
    api
      ..get('/api/v1/matches/requests/mine', [])
      ..get('/api/v1/games', springPage([gameJson()]))
      ..post('/api/v1/matches/requests', {
        'id': 'mr1',
        'game': gameJson(),
        'availableFrom': null,
        'availableTo': null,
        'status': 'ACTIVE',
      });
    await pumpApp(tester, api: api, location: '/matching');

    expect(find.text('No active match requests.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('match-pick-game')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('pick-g1')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('match-submit')));
    await settle(tester);

    final body = api.calls('POST', '/api/v1/matches/requests').single.data as Map;
    expect(body['gameId'], 'g1');
    expect(find.byKey(const ValueKey('match-request-mr1')), findsOneWidget);
  });
}
