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
  });

  testWidgets('home shows greeting, matches, upcoming events and the feed',
      (tester) async {
    await pumpApp(tester, api: api);

    expect(find.textContaining('Mia Meeple'), findsWidgets);
    expect(find.text('Match suggestions'), findsOneWidget);
    expect(find.text('Catan Night'), findsOneWidget);
    expect(find.text('Great game night'), findsOneWidget);
    expect(find.textContaining('to their collection'), findsOneWidget);
    // Unread badge.
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('liking a post is optimistic and calls the API', (tester) async {
    api.post('/api/v1/posts/p1/like', const FakeResponse.noContent());
    await pumpApp(tester, api: api);

    await tester.tap(find.byKey(const ValueKey('like-p1')));
    await settle(tester);

    expect(api.called('POST', '/api/v1/posts/p1/like'), isTrue);
    expect(find.text('3 likes'), findsOneWidget);
  });

  testWidgets('a failed like is reverted and reported', (tester) async {
    api.post(
      '/api/v1/posts/p1/like',
      const FakeResponse.error(500, 'INTERNAL'),
    );
    await pumpApp(tester, api: api);

    await tester.tap(find.byKey(const ValueKey('like-p1')));
    await settle(tester);

    expect(find.text('2 likes'), findsOneWidget);
    expect(find.textContaining('Something went wrong'), findsOneWidget);
  });

  testWidgets('empty feed for a user without friends offers Find Friends',
      (tester) async {
    api
      ..get('/api/v1/feed', cursor([]))
      ..get('/api/v1/users/me/stats', {'friends': 0});
    await pumpApp(tester, api: api);

    expect(find.text('Your feed is quiet.'), findsOneWidget);
    expect(find.text('Find Friends'), findsOneWidget);
  });

  testWidgets('feed error shows retry', (tester) async {
    api.get('/api/v1/feed', const FakeResponse.error(500, 'INTERNAL'));
    await pumpApp(tester, api: api);

    expect(find.text("Couldn't load your feed."), findsOneWidget);
    api.get('/api/v1/feed', cursor([]));
    await tester.tap(find.text('Try again'));
    await settle(tester);
    expect(find.text("Couldn't load your feed."), findsNothing);
  });

  testWidgets('dismissing a match suggestion removes the card',
      (tester) async {
    api.post('/api/v1/matches/mg1/dismiss', const FakeResponse.noContent());
    await pumpApp(tester, api: api);

    await tester.tap(find.byKey(const ValueKey('match-dismiss-mg1')));
    await settle(tester);

    expect(api.called('POST', '/api/v1/matches/mg1/dismiss'), isTrue);
    expect(find.text('Match suggestions'), findsNothing);
  });

  testWidgets('the create sheet lists post, event, game and match',
      (tester) async {
    await pumpApp(tester, api: api);

    await tester.tap(find.byKey(const Key('create-fab')));
    await settle(tester);

    expect(find.text('Post a game night'), findsOneWidget);
    expect(find.byKey(const ValueKey('create-/events/create')), findsOneWidget);
    expect(find.text('Add a game'), findsOneWidget);
    expect(find.text('Find players'), findsOneWidget);
  });
}
