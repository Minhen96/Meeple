import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeple_hearth/features/auth/presentation/register_screen.dart';

import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';
import '../helpers/harness.dart';

/// Branches added by the profile / friends / settings / onboarding / auth
/// restyle (web phone view parity).
void main() {
  late FakeApi api;

  setUp(() {
    api = FakeApi();
    stubDefaults(api);
  });

  test('password strength follows the web register rules', () {
    expect(PasswordStrength.of('short'), PasswordStrength.weak);
    expect(PasswordStrength.of('onlyletters'), PasswordStrength.weak);
    expect(PasswordStrength.of('letters123'), PasswordStrength.good);
    expect(PasswordStrength.of('longer-pass-123!'), PasswordStrength.strong);
  });

  testWidgets('register shows the password strength bar', (tester) async {
    final c = await pumpApp(tester, api: api, signedIn: false);
    await push(tester, c, '/auth/register');
    expect(find.text('table.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(2), 'letters123');
    await tester.pump();
    expect(find.byKey(const ValueKey('strength-good')), findsOneWidget);
  });

  testWidgets('verify email: expired link, then resend', (tester) async {
    api
      ..post(
        '/api/v1/auth/verify-email',
        const FakeResponse.error(400, 'TOKEN_EXPIRED', 'Expired'),
      )
      ..post('/api/v1/auth/resend-verification', {'message': 'ok'});
    final c = await pumpApp(tester, api: api, signedIn: false);
    await push(tester, c, '/auth/verify-email?token=bad');
    expect(find.text('Link expired'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('verify-email')), 'me@x.com');
    await tester.tap(find.byKey(const Key('verify-resend')));
    await settle(tester);
    expect(api.called('POST', '/api/v1/auth/resend-verification'), isTrue);
    expect(find.byKey(const Key('verify-resent')), findsOneWidget);
  });

  testWidgets('reset password without a token offers a new link',
      (tester) async {
    final c = await pumpApp(tester, api: api, signedIn: false);
    await push(tester, c, '/auth/reset-password');
    expect(find.text('Invalid link'), findsOneWidget);
    await tester.tap(find.text('Request a new link'));
    await settle(tester);
    expect(find.text('Reset your password'), findsOneWidget);
  });

  group('friend button', () {
    void stubProfile(String status) {
      api
        ..get('/api/v1/users/f1',
            userJson(id: 'f1', username: 'fred', displayName: 'Fred'))
        ..get('/api/v1/users/f1/stats', {'gamesOwned': 1, 'sessions': 2})
        ..get('/api/v1/users/f1/posts', cursor([]))
        ..get('/api/v1/users/f1/tagged-posts', cursor([]))
        ..get('/api/v1/users/f1/games', <Object>[])
        ..get('/api/v1/users/f1/friend-status',
            {'status': status, 'requestId': 'fr1'});
    }

    testWidgets('received request: Accept Request', (tester) async {
      stubProfile('PENDING_RECEIVED');
      api.post(
          '/api/v1/friend-requests/fr1/accept', const FakeResponse.noContent());
      await pumpApp(tester, api: api, location: '/profile/f1');
      expect(find.text('Accept Request'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('accept-f1')));
      await settle(tester);
      expect(api.called('POST', '/api/v1/friend-requests/fr1/accept'), isTrue);
      expect(find.byKey(const ValueKey('friends-f1')), findsOneWidget);
    });

    testWidgets('friends: unfriend after confirming; collection visible',
        (tester) async {
      stubProfile('FRIENDS');
      api.delete('/api/v1/friends/f1', const FakeResponse.noContent());
      await pumpApp(tester, api: api, location: '/profile/f1');

      await tester.tap(find.text('Collection'));
      await settle(tester);
      expect(find.text('No games in this collection yet.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('friends-f1')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('confirm-sheet-confirm')));
      await settle(tester);
      expect(api.called('DELETE', '/api/v1/friends/f1'), isTrue);
    });

    testWidgets('not friends: collection is friends-only; report from menu',
        (tester) async {
      stubProfile('NONE');
      await pumpApp(tester, api: api, location: '/profile/f1');
      await tester.tap(find.text('Collection'));
      await settle(tester);
      expect(
        find.text('Add each other as friends to see this collection.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('user-profile-menu')));
      await settle(tester);
      expect(find.byKey(const Key('profile-report')), findsOneWidget);
      expect(find.byKey(const Key('profile-share')), findsOneWidget);
    });

    testWidgets('compact chips for every status in Find', (tester) async {
      api
        ..get('/api/v1/friend-requests/received', cursor([]))
        ..get('/api/v1/friend-requests/sent', cursor([]))
        ..get('/api/v1/users/suggestions', {
          'data': [
            {
              ...summaryJson('a1', 'Ann'),
              'friendshipStatus': 'pending_received'
            },
            {...summaryJson('b1', 'Ben'), 'friendshipStatus': 'friends'},
            {...summaryJson('c1', 'Cat'), 'friendshipStatus': 'pending_sent'},
            {...summaryJson('d1', 'Dan'), 'friendshipStatus': 'blocked'},
          ],
          'meta': {'page': 1, 'limit': 10, 'total': 4, 'hasMore': false},
        });
      await pumpApp(tester, api: api, location: '/friends');
      await tester.tap(find.text('Find'));
      await settle(tester);
      for (final key in [
        'accept-a1',
        'decline-a1',
        'friends-b1',
        'pending-c1',
        'unblock-d1'
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
      }
    });
  });

  testWidgets('onboarding add game: quick add from the sheet', (tester) async {
    api
      ..get('/api/v1/games', springPage([gameJson()]))
      ..put('/api/v1/users/me/games/g1', userGameJson());
    final c = await pumpApp(tester, api: api);
    await push(tester, c, '/onboarding/add-game');
    expect(find.text('POPULAR GAMES'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-game-g1')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('quick-add-confirm')));
    await settle(tester);
    expect(api.called('PUT', '/api/v1/users/me/games/g1'), isTrue);
  });
}
