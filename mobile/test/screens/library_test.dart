import 'package:dio/dio.dart';
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
      ..get('/api/v1/games', springPage([gameJson(), gameJson(id: 'g9', title: 'Root')]))
      ..get('/api/v1/games/g1', gameJson())
      ..get('/api/v1/games/g1/friends', [
        {'user': summaryJson('f1', 'Fred'), 'playCount': 4, 'personalRating': 9, 'isOwned': true},
      ])
      ..get('/api/v1/games/g1/reviews', [
        {'user': summaryJson('f1', 'Fred'), 'personalRating': 9, 'notes': 'Classic', 'playCount': 4},
      ])
      ..get('/api/v1/games/g1/sessions', cursor([postJson()]))
      ..get('/api/v1/games/g1/how-to-play', {
        'status': 'ready',
        'data': {
          'overview': 'Build settlements',
          'setup': 'Place the board',
          'winCondition': {'type': 'points', 'details': 'First to 10'},
          'actions': [
            {'name': 'Trade', 'effect': 'Swap cards'},
          ],
          'faq': ['Can I trade on others turns? No.'],
        },
        'disclaimer': 'Based on the official rulebook.',
      })
      ..get('/api/v1/users/me/games/g1/plays', [
        {'id': 'pl1', 'playedAt': '2026-08-01T10:00:00Z', 'notes': 'Won'},
      ]);
  });

  testWidgets('library tabs: all games grid and wishlist from isWishlisted',
      (tester) async {
    await pumpApp(tester, api: api, location: '/library');

    expect(find.text('Catan'), findsWidgets);
    expect(find.text('Root'), findsOneWidget);

    await tester.tap(find.text('Wishlist'));
    await settle(tester);
    expect(find.text('Azul'), findsOneWidget);

    await tester.tap(find.text('Favorites'));
    await settle(tester);
    expect(find.text('Wingspan'), findsOneWidget);

    await tester.tap(find.text('My Collection'));
    await settle(tester);
    expect(find.text('Wingspan'), findsWidgets);
  });

  testWidgets('filters narrow results client-side', (tester) async {
    await pumpApp(tester, api: api, location: '/library');

    await tester.scrollUntilVisible(
      find.text('5+ players'),
      100,
      scrollable: find
          .ancestor(of: find.text('2+ players'), matching: find.byType(Scrollable))
          .first,
    );
    await settle(tester);
    await tester.tap(find.text('5+ players'));
    await settle(tester);

    expect(find.textContaining('No games'), findsOneWidget);
  });

  testWidgets('search query is debounced and sent as q', (tester) async {
    await pumpApp(tester, api: api, location: '/library');

    await tester.enterText(find.byKey(const Key('library-search')), 'cat');
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);

    expect(
      api.calls('GET', '/api/v1/games').any((r) => r.queryParameters['q'] == 'cat'),
      isTrue,
    );
  });

  testWidgets('empty wishlist shows its empty state', (tester) async {
    api.get('/api/v1/users/me/games', [userGameJson()]);
    await pumpApp(tester, api: api, location: '/library?filter=wishlist');

    expect(find.text('No games on your wishlist yet.'), findsOneWidget);
  });

  testWidgets('game detail renders hero, info bar, guide and tabs',
      (tester) async {
    await pumpApp(tester, api: api, location: '/library/g1');

    expect(find.text('Catan'), findsWidgets);
    expect(find.text('Owned by 1 friend'), findsOneWidget);
    expect(find.text('3–4'), findsOneWidget);
    expect(find.text('In Collection'), findsOneWidget);

    await tester.tap(find.byKey(const Key('how-to-play')));
    await settle(tester);
    expect(find.text('Build settlements'), findsOneWidget);
    expect(find.textContaining('First to 10'), findsOneWidget);

    await tester.tap(find.text('Reviews'));
    await settle(tester);
    expect(find.text('Classic'), findsOneWidget);

    await tester.tap(find.text('Sessions'));
    await settle(tester);
    expect(find.text('Great game night'), findsOneWidget);

    await tester.tap(find.text('Friends').last);
    await settle(tester);
    expect(find.text('4 plays'), findsOneWidget);
  });

  testWidgets('wishlist and favorite toggles upsert the multi-boolean entry',
      (tester) async {
    api.put('/api/v1/users/me/games/g1', userGameJson(wishlisted: true));
    await pumpApp(tester, api: api, location: '/library/g1');

    await tester.tap(find.byKey(const Key('game-wishlist')));
    await settle(tester);

    final put = api.calls('PUT', '/api/v1/users/me/games/g1').single;
    expect((put.data as Map)['isWishlisted'], isTrue);
    expect((put.data as Map)['isOwned'], isTrue);
    expect(find.text('On Wishlist'), findsOneWidget);
  });

  testWidgets('adding an untracked game to the collection', (tester) async {
    api
      ..get('/api/v1/games/g9', gameJson(id: 'g9', title: 'Root'))
      ..put('/api/v1/users/me/games/g9', userGameJson(gameId: 'g9', title: 'Root'));
    await pumpApp(tester, api: api, location: '/library/g9');

    await tester.tap(find.byKey(const Key('game-add-collection')));
    await settle(tester);

    expect(api.called('PUT', '/api/v1/users/me/games/g9'), isTrue);
    expect(find.text('In Collection'), findsOneWidget);
  });

  testWidgets('logging a play posts the plays endpoint', (tester) async {
    api.post('/api/v1/users/me/games/g1/plays', {'id': 'pl2', 'playedAt': '2026-09-01T00:00:00Z'});
    await pumpApp(tester, api: api, location: '/library/g1');

    await tester.tap(find.byKey(const Key('game-log-play')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('log-play-save')));
    await settle(tester);

    expect(api.called('POST', '/api/v1/users/me/games/g1/plays'), isTrue);
    expect(find.text('Play logged!'), findsOneWidget);
  });

  testWidgets('collection entry sheet saves a rating and shows plays',
      (tester) async {
    api.put('/api/v1/users/me/games/g1', userGameJson());
    await pumpApp(tester, api: api, location: '/library/g1');

    await tester.tap(find.byKey(const Key('game-in-collection')));
    await settle(tester);
    expect(find.text('Won'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await settle(tester);
    final put = api.calls('PUT', '/api/v1/users/me/games/g1').single;
    expect((put.data as Map)['personalRating'], 8.5);
  });

  testWidgets('missing game shows not found', (tester) async {
    await pumpApp(tester, api: api, location: '/library/nope');
    expect(find.text("This game doesn't exist or was removed."), findsOneWidget);
  });

  testWidgets('AI rules assistant sends the last 3 pairs as history',
      (tester) async {
    var n = 0;
    api.on('POST', '/api/v1/ai/rules', (RequestOptions r) {
      n++;
      return FakeResponse({
        'data': {
          'answer': 'Answer $n',
          'sourceMode': 'rulebook',
          'disclaimer': 'x',
          'cached': false,
        },
      });
    });
    await pumpApp(tester, api: api, location: '/library/g1');

    await tester.tap(find.byKey(const Key('game-ai')));
    await settle(tester);
    expect(find.text('How do you win?'), findsOneWidget);

    for (var i = 1; i <= 4; i++) {
      await tester.enterText(find.byKey(const Key('ai-input')), 'Q$i');
      await tester.tap(find.byKey(const Key('ai-send')));
      await settle(tester);
    }
    expect(find.text('Answer 4'), findsOneWidget);

    final last = api.calls('POST', '/api/v1/ai/rules').last.data as Map;
    expect(last['gameId'], 'g1');
    expect(last['question'], 'Q4');
    final history = last['conversationHistory'] as List;
    expect(history, hasLength(3));
    expect((history.first as Map)['question'], 'Q1');
    expect((history.last as Map)['answer'], 'Answer 3');
  });

  testWidgets('AI rate limit is explained', (tester) async {
    api.post(
      '/api/v1/ai/rules',
      const FakeResponse.error(429, 'RATE_LIMIT_EXCEEDED'),
    );
    await pumpApp(tester, api: api, location: '/library/g1');

    await tester.tap(find.byKey(const Key('game-ai')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('ai-input')), 'How?');
    await tester.tap(find.byKey(const Key('ai-send')));
    await settle(tester);

    expect(find.textContaining('20 questions/day'), findsOneWidget);
  });

  testWidgets('without a rulebook the assistant asks first', (tester) async {
    api.get('/api/v1/games/g1', gameJson(hasRulebook: false));
    await pumpApp(tester, api: api, location: '/library/g1');

    await tester.tap(find.byKey(const Key('game-ai')));
    await settle(tester);
    expect(find.textContaining('No rulebook available'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai-ask-anyway')));
    await settle(tester);
    expect(find.byKey(const Key('ai-input')), findsOneWidget);
  });
}
