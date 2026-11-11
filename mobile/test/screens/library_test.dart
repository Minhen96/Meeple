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

  testWidgets('filter and sort sheets send discovery filters and sort',
      (tester) async {
    await pumpApp(tester, api: api, location: '/library');
    expect(find.text('Library Feed'), findsOneWidget);
    expect(find.text('2 RESULTS'), findsOneWidget);
    expect(find.byKey(const Key('library-spotlight')), findsOneWidget);

    await tester.tap(find.byKey(const Key('library-filters')));
    await settle(tester);
    expect(find.text('Discovery Filters'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('genre-Strategy')));
    await tester.tap(find.byKey(const ValueKey('complexity-0')));
    await tester.enterText(find.byKey(const Key('filter-min-players')), '2');
    await tester.enterText(find.byKey(const Key('filter-max-time')), '60');
    await tester.enterText(find.byKey(const Key('filter-min-rating')), '7.5');
    await tester.tap(find.byKey(const Key('filter-apply')));
    await settle(tester);

    var last = api.calls('GET', '/api/v1/games').last.queryParameters;
    expect(last['genre'], 'Strategy');
    expect(last['minPlayers'], 2);
    expect(last['maxPlaytime'], 60);
    expect(last['minComplexity'], 1.0);
    expect(last['minRating'], 7.5);
    // Badge: genre, complexity, players, playtime, rating.
    expect(
      find.descendant(
        of: find.byKey(const Key('library-filters')),
        matching: find.text('5'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('library-sort')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('sort-usersRated,desc')));
    await settle(tester);
    last = api.calls('GET', '/api/v1/games').last.queryParameters;
    expect(last['sort'], 'usersRated,desc');
    expect(last['genre'], 'Strategy');

    await tester.tap(find.byKey(const Key('library-filters')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('filter-reset')));
    await settle(tester);
    last = api.calls('GET', '/api/v1/games').last.queryParameters;
    expect(last.containsKey('genre'), isFalse);
    expect(last['sort'], 'usersRated,desc');
  });

  testWidgets('empty catalogue and recommended sort show the feed empty states',
      (tester) async {
    api.get('/api/v1/games', springPage(<Object>[]));
    await pumpApp(tester, api: api, location: '/library');
    expect(find.text('The library feels empty'), findsOneWidget);

    await tester.tap(find.byKey(const Key('library-sort')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('sort-recommended')));
    await settle(tester);
    expect(find.text('No recommendations yet'), findsOneWidget);
  });

  testWidgets('collection tab: badges, star rating and local search',
      (tester) async {
    api
      ..get('/api/v1/users/me/games', [
        userGameJson(wishlisted: true, favorited: true),
        userGameJson(gameId: 'g2', title: 'Azul'),
      ])
      ..put('/api/v1/users/me/games/g1', userGameJson());
    await pumpApp(tester, api: api, location: '/library?filter=collection');

    expect(find.text('OWNED'), findsNWidgets(2));
    expect(find.text('WISHLIST'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('game-g1')),
        matching: find.byKey(const ValueKey('star-2')),
      ),
    );
    await settle(tester);
    final put = api.calls('PUT', '/api/v1/users/me/games/g1').single;
    expect((put.data as Map)['personalRating'], 4.0);

    await tester.enterText(find.byKey(const Key('library-search')), 'azu');
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);
    expect(find.text('Catan'), findsNothing);
    expect(find.text('Azul'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('library-search')), 'zzz');
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);
    expect(find.textContaining('No games in this list match'), findsOneWidget);
  });

  testWidgets('empty shelf browse button returns to All Games',
      (tester) async {
    api.get('/api/v1/users/me/games', <Object>[]);
    await pumpApp(tester, api: api, location: '/library?filter=collection');
    expect(find.text('Your shelf is empty.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('library-browse')));
    await settle(tester);
    expect(find.text('Library Feed'), findsOneWidget);
  });

  testWidgets('spotlight save favorites it and explore opens the game',
      (tester) async {
    api.put('/api/v1/users/me/games/g1', userGameJson(favorited: true));
    await pumpApp(tester, api: api, location: '/library');

    await tester.tap(find.byKey(const Key('spotlight-save')));
    await settle(tester);
    final put = api.calls('PUT', '/api/v1/users/me/games/g1').single;
    expect((put.data as Map)['isFavorited'], isTrue);
    expect(find.text('Gloomhaven added to favorites!'), findsOneWidget);

    await tester.tap(find.byKey(const Key('spotlight-explore')));
    await settle(tester);
    expect(find.byKey(const Key('game-my-panel')), findsOneWidget);
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

  testWidgets('game detail renders hero, stats, guide and tabs',
      (tester) async {
    await pumpApp(tester, api: api, location: '/library/g1');

    expect(find.text('Catan'), findsWidgets);
    expect(find.text('Owned by 1 friend'), findsOneWidget);
    expect(find.text('3–4'), findsOneWidget);
    expect(find.text('90 min'), findsOneWidget);
    expect(find.text('BGG #500'), findsOneWidget);
    expect(find.text('(1,000 ratings)'), findsOneWidget);
    expect(find.text('by Klaus Teuber'), findsOneWidget);
    expect(find.text('In Collection'), findsOneWidget);
    expect(find.text('PLAY HISTORY (3)'), findsOneWidget);
    expect(find.text('Won'), findsOneWidget);

    await tester.tap(find.text('Read more'));
    await settle(tester);
    expect(find.text('Show less'), findsOneWidget);

    await tester.tap(find.byKey(const Key('how-to-play')));
    await settle(tester);
    expect(find.text('Build settlements'), findsOneWidget);
    expect(find.textContaining('First to 10'), findsOneWidget);
    expect(find.text('Based on the official rulebook.'), findsOneWidget);

    await tester.tap(find.text('Reviews'));
    await settle(tester);
    expect(find.text('Classic'), findsOneWidget);

    await tester.tap(find.text('Sessions'));
    await settle(tester);
    expect(find.textContaining('Great game night'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('game-tab-friends')));
    await tester.tap(find.byKey(const ValueKey('game-tab-friends')));
    await settle(tester);
    expect(find.text('4 plays'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('game-tab-overview')));
    await tester.tap(find.byKey(const ValueKey('game-tab-overview')));
    await settle(tester);
    await tester.tap(find.text('Owned by 1 friend'));
    await settle(tester);
    expect(find.text('4 plays'), findsOneWidget);
  });

  testWidgets('game detail tab errors and empty states', (tester) async {
    api
      ..get('/api/v1/games/g1/reviews', const FakeResponse.error(500, 'X'))
      ..get('/api/v1/games/g1/friends', <Object>[])
      ..get('/api/v1/games/g1/sessions',
          const FakeResponse.error(404, 'NOT_FOUND'))
      ..get('/api/v1/games/g1/how-to-play', {
        'status': 'generating',
        'progress': 40,
      });
    await pumpApp(tester, api: api, location: '/library/g1');

    await tester.tap(find.text('Reviews'));
    await settle(tester);
    expect(find.text('Could not load this. Try again.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await settle(tester);

    await tester.tap(find.text('Sessions'));
    await settle(tester);
    expect(find.text('No sessions logged yet.'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('game-tab-friends')));
    await tester.tap(find.byKey(const ValueKey('game-tab-friends')));
    await settle(tester);
    expect(find.text('None of your friends own this yet.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('how-to-play')));
    await settle(tester, 3);
    expect(find.text('Generating your guide…'), findsOneWidget);
    // Finish polling so no timer is left pending.
    api.get('/api/v1/games/g1/how-to-play', {'status': 'not_generated'});
    await tester.pump(const Duration(seconds: 4));
    await settle(tester);
    expect(find.text('Generate a rules guide'), findsOneWidget);
  });

  testWidgets('how to play: generate a guide', (tester) async {
    api
      ..get('/api/v1/games/g1/how-to-play', {'status': 'not_generated'})
      ..post('/api/v1/games/g1/how-to-play/generate', {
        'status': 'ready',
        'sourceMode': 'general',
        'data': {
          'tips': ['Trade early'],
        },
      });
    await pumpApp(tester, api: api, location: '/library/g1');
    await tester.tap(find.byKey(const Key('how-to-play')));
    await settle(tester);
    expect(find.text('Generate a rules guide'), findsOneWidget);
    await tester.tap(find.byKey(const Key('htp-generate')));
    await settle(tester);
    expect(find.text('AI GENERAL KNOWLEDGE'), findsOneWidget);
    expect(find.text('TIPS FOR NEW PLAYERS'), findsOneWidget);
    expect(find.text('• Trade early'), findsOneWidget);
  });

  testWidgets('my panel saves notes on blur and deletes a play',
      (tester) async {
    api
      ..put('/api/v1/users/me/games/g1', userGameJson())
      ..delete('/api/v1/users/me/plays/pl1', const FakeResponse.noContent());
    await pumpApp(tester, api: api, location: '/library/g1');

    await tester.enterText(find.byKey(const Key('game-notes')), 'House rule');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    final put = api.calls('PUT', '/api/v1/users/me/games/g1').single;
    expect((put.data as Map)['notes'], 'House rule');

    await tester.tap(find.byKey(const ValueKey('play-delete-pl1')));
    await settle(tester);
    expect(find.text('Play deleted'), findsOneWidget);
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
    api.post('/api/v1/users/me/games/g1/plays',
        {'id': 'pl2', 'playedAt': '2026-09-01T00:00:00Z'});
    await pumpApp(tester, api: api, location: '/library/g1');

    await tester.tap(find.byKey(const Key('game-log-play')));
    await settle(tester);
    expect(find.text('Log a Play'), findsOneWidget);
    expect(find.text('Selected'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('log-play-duration')), '45');
    await tester.enterText(find.byKey(const Key('log-play-players')), '3');
    await tester.tap(find.byKey(const Key('log-play-save')));
    await settle(tester);

    final body = api.calls('POST', '/api/v1/users/me/games/g1/plays').single.data
        as Map;
    expect(body['durationMinutes'], 45);
    expect(body['playerCount'], 3);
    expect(find.text('Play logged for Catan!'), findsOneWidget);
  });

  testWidgets('your rating stars save the personal rating', (tester) async {
    api.put('/api/v1/users/me/games/g1', userGameJson());
    await pumpApp(tester, api: api, location: '/library/g1');

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('game-my-panel')),
        matching: find.byKey(const ValueKey('star-5')),
      ),
    );
    await settle(tester);
    final put = api.calls('PUT', '/api/v1/users/me/games/g1').single;
    // 8.5 shows five stars; tapping the current star clears it.
    expect((put.data as Map)['personalRating'], 0.0);
  });

  testWidgets('owned toggle removes the game from the collection',
      (tester) async {
    api.delete('/api/v1/users/me/games/g1', const FakeResponse.noContent());
    await pumpApp(tester, api: api, location: '/library/g1');

    await tester.tap(find.byKey(const Key('game-in-collection')));
    await settle(tester);
    expect(api.called('DELETE', '/api/v1/users/me/games/g1'), isTrue);
    expect(find.text('Own'), findsOneWidget);
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

    expect(find.textContaining('daily limit (20 questions)'), findsOneWidget);
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
