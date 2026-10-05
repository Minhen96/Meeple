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
  });

  group('auth forms', () {
    testWidgets('register success goes to email verification', (tester) async {
      api.post('/api/v1/auth/register', {'message': 'ok'});
      final c = await pumpApp(tester, api: api, signedIn: false);
      await push(tester, c, '/auth/register');

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'NewUser');
      await tester.enterText(fields.at(1), 'new@example.com');
      await tester.enterText(fields.at(2), 'secret123');
      await tester.enterText(fields.at(3), 'secret123');
      await tester.tap(find.text('Create Account').last);
      await settle(tester);

      expect(api.calls('POST', '/api/v1/auth/register').single.data, {
        'username': 'newuser',
        'email': 'new@example.com',
        'password': 'secret123',
      });
      expect(find.text('Check your inbox'), findsOneWidget);
    });

    testWidgets('register conflict shows a snackbar; empty form validates',
        (tester) async {
      api.post('/api/v1/auth/register',
          const FakeResponse.error(409, 'USERNAME_TAKEN', 'Username is taken'));
      final c = await pumpApp(tester, api: api, signedIn: false);
      await push(tester, c, '/auth/register');

      await tester.tap(find.text('Create Account').last);
      await settle(tester);
      expect(api.called('POST', '/api/v1/auth/register'), isFalse);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'taken');
      await tester.enterText(fields.at(1), 'x@example.com');
      await tester.enterText(fields.at(2), 'secret123');
      await tester.enterText(fields.at(3), 'secret123');
      await tester.tap(find.text('Create Account').last);
      await settle(tester);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('forgot password: validation, success and failure',
        (tester) async {
      var fail = true;
      api.post(
        '/api/v1/auth/forgot-password',
        (RequestOptions _) => fail
            ? const FakeResponse.error(429, 'RATE_LIMITED', 'Slow down')
            : const FakeResponse({'data': {'message': 'ok'}}),
      );
      final c = await pumpApp(tester, api: api, signedIn: false);
      await push(tester, c, '/auth/forgot-password');

      await tester.tap(find.text('Send Reset Link'));
      await settle(tester);
      expect(api.called('POST', '/api/v1/auth/forgot-password'), isFalse);

      await tester.enterText(find.byType(TextFormField), 'not-an-email');
      await tester.tap(find.text('Send Reset Link'));
      await settle(tester);
      expect(api.called('POST', '/api/v1/auth/forgot-password'), isFalse);

      await tester.enterText(find.byType(TextFormField), 'me@example.com');
      await tester.tap(find.text('Send Reset Link'));
      await settle(tester);
      expect(find.byType(SnackBar), findsOneWidget);

      fail = false;
      await tester.tap(find.text('Send Reset Link'));
      await settle(tester);
      expect(find.text('Check your inbox'), findsOneWidget);
      await tester.tap(find.text('Back to Sign In'));
      await settle(tester);
    });

    testWidgets('reset password: mismatch, failure and success',
        (tester) async {
      var fail = true;
      api.post(
        '/api/v1/auth/reset-password',
        (RequestOptions _) => fail
            ? const FakeResponse.error(400, 'TOKEN_EXPIRED', 'Expired')
            : const FakeResponse({'data': {'message': 'ok'}}),
      );
      final c = await pumpApp(tester, api: api, signedIn: false);
      await push(tester, c, '/auth/reset-password?token=t1');

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'newsecret1');
      await tester.enterText(fields.at(1), 'different1');
      await tester.tap(find.text('Reset Password').last);
      await settle(tester);
      expect(api.called('POST', '/api/v1/auth/reset-password'), isFalse);

      await tester.enterText(fields.at(1), 'newsecret1');
      await tester.tap(find.text('Reset Password').last);
      await settle(tester);
      expect(find.byType(SnackBar), findsOneWidget);

      fail = false;
      await tester.tap(find.text('Reset Password').last);
      await settle(tester);
      expect(api.calls('POST', '/api/v1/auth/reset-password').last.data,
          {'token': 't1', 'newPassword': 'newsecret1'});
      expect(find.text('Password updated!'), findsOneWidget);
    });

    testWidgets('reset password without a token', (tester) async {
      final c = await pumpApp(tester, api: api, signedIn: false);
      await push(tester, c, '/auth/reset-password');
      expect(api.called('POST', '/api/v1/auth/reset-password'), isFalse);
    });
  });

  group('own profile menu', () {
    for (final (key, title) in [
      ('friends', 'Friends'),
      ('bookmarks', 'Saved posts'),
      ('matching', 'Matching'),
      ('settings', 'Settings'),
    ]) {
      testWidgets('opens $key', (tester) async {
        api
          ..get('/api/v1/users/me/posts', cursor([]))
          ..get('/api/v1/users/me/tagged-posts', cursor([]))
          ..get('/api/v1/users/me/bookmarks', cursor([]))
          ..get('/api/v1/matches/requests/mine', <Object>[])
          ..get('/api/v1/friend-requests/received', cursor([]))
          ..get('/api/v1/friend-requests/sent', cursor([]));
        await pumpApp(tester, api: api, location: '/profile');
        await tester.tap(find.byKey(const Key('profile-menu')));
        await settle(tester);
        await tester.tap(find.byKey(ValueKey('profile-menu-$key')));
        await settle(tester);
        expect(find.text(title), findsWidgets);
      });
    }

    testWidgets('log out from the menu', (tester) async {
      api
        ..get('/api/v1/users/me/posts', cursor([]))
        ..get('/api/v1/users/me/tagged-posts', cursor([]))
        ..post('/api/v1/auth/logout', const FakeResponse.noContent());
      await pumpApp(tester, api: api, location: '/profile');
      await tester.tap(find.byKey(const Key('profile-menu')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('profile-menu-logout')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('confirm-sheet-confirm')));
      await settle(tester);
      expect(api.called('POST', '/api/v1/auth/logout'), isTrue);
      expect(find.text('Welcome back'), findsOneWidget);
    });
  });

  group('events', () {
    testWidgets('empty past list and calendar errors / day sheet',
        (tester) async {
      api
        ..get('/api/v1/events', (RequestOptions r) => FakeResponse({
              'data': r.queryParameters['scope'] == 'past'
                  ? <Object>[]
                  : [eventJson()],
            }))
        ..get('/api/v1/events/calendar', [
          eventJson(at: DateTime.now().add(const Duration(hours: 1))),
        ]);
      await pumpApp(tester, api: api, location: '/events');
      await tester.tap(find.text('Past'));
      await settle(tester);
      expect(find.text('No past events.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('events-toggle-view')));
      await settle(tester);
      expect(find.byKey(const Key('events-calendar')), findsOneWidget);
      final today = DateTime.now().add(const Duration(hours: 1));
      await tester.tap(find
          .descendant(
            of: find.byKey(const Key('events-calendar')),
            matching: find.text('${today.day}'),
          )
          .first);
      await settle(tester);
      expect(find.text('Catan Night'), findsWidgets);
      expect(api.called('GET', '/api/v1/events/calendar'), isTrue);
    });

    testWidgets('calendar shows an error and an empty month', (tester) async {
      api.get('/api/v1/events/calendar',
          const FakeResponse.error(400, 'INVALID_RANGE', 'Bad range'));
      await pumpApp(tester, api: api, location: '/events?view=calendar');
      expect(find.text('Bad range'), findsOneWidget);
      expect(find.text('No events this month.'), findsOneWidget);
    });
  });

  group('friends & matching', () {
    testWidgets('empty friends, sent request cancel, decline, no suggestions',
        (tester) async {
      api
        ..get('/api/v1/friends', {
          'data': <Object>[],
          'meta': {'page': 1, 'limit': 30, 'total': 0, 'hasMore': false},
        })
        ..get('/api/v1/friend-requests/received', {
          'data': [
            {'id': 'fr8', 'sender': summaryJson('f8', 'Ola'),
              'receiver': summaryJson('me')},
          ],
          'meta': {'page': 1, 'limit': 30, 'total': 1, 'hasMore': false},
        })
        ..get('/api/v1/friend-requests/sent', {
          'data': [
            {'id': 'fr9', 'sender': summaryJson('me'),
              'receiver': summaryJson('f9', 'Pia')},
          ],
          'meta': {'page': 1, 'limit': 30, 'total': 1, 'hasMore': false},
        })
        ..post('/api/v1/friend-requests/fr8/decline', {'id': 'fr8'})
        ..delete('/api/v1/users/f9/friend-request', const FakeResponse.noContent())
        ..get('/api/v1/users/suggestions', {
          'data': <Object>[],
          'meta': {'page': 1, 'limit': 10, 'total': 0, 'hasMore': false},
        });
      await pumpApp(tester, api: api, location: '/friends');
      expect(find.text('No friends yet'), findsOneWidget);

      await tester.tap(find.text('Requests'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('request-decline-fr8')));
      await settle(tester);
      expect(api.called('POST', '/api/v1/friend-requests/fr8/decline'), isTrue);
      await tester.tap(find.text('Cancel request'));
      await settle(tester);
      expect(api.called('DELETE', '/api/v1/users/f9/friend-request'), isTrue);
      expect(find.text('Pia'), findsNothing);

      await tester.tap(find.text('Find'));
      await settle(tester);
      expect(find.text('No suggestions yet. Search for friends by username.'),
          findsOneWidget);
    });

    testWidgets('matching: submit without game, cancel request, no '
        'suggestions', (tester) async {
      api
        ..get('/api/v1/matches/suggestions', <Object>[])
        ..get('/api/v1/matches/requests/mine', [
          {
            'id': 'mr1',
            'game': gameJson(),
            'availableFrom': '2026-12-01T10:00:00Z',
            'availableTo': '2026-12-01T14:00:00Z',
            'status': 'ACTIVE',
          },
        ])
        ..delete('/api/v1/matches/requests/mr1', const FakeResponse.noContent());
      await pumpApp(tester, api: api, location: '/matching');
      expect(find.text('No match suggestions right now.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('match-submit')));
      await settle(tester);
      expect(find.text('Pick a game first.'), findsOneWidget);

      await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('match-request-mr1')),
        matching: find.text('Cancel'),
      ));
      await settle(tester);
      expect(api.called('DELETE', '/api/v1/matches/requests/mr1'), isTrue);
      expect(find.byKey(const ValueKey('match-request-mr1')), findsNothing);
    });
  });
}
