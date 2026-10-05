import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';
import '../helpers/harness.dart';

/// Login responses carry tokens as cookies.
FakeHandler _loginOk(Map<String, dynamic> user) =>
    (RequestOptions _) => FakeResponse.signedIn({'data': user});

void main() {
  late FakeApi api;

  setUp(() {
    api = FakeApi();
    stubDefaults(api);
  });

  group('settings', () {
    testWidgets('root lists sections and switches language to Chinese',
        (tester) async {
      api.put('/api/v1/users/me', userJson(preferredLanguage: 'zh-CN'));
      await pumpApp(tester, api: api, location: '/settings');

      expect(find.text('ACCOUNT'), findsOneWidget);
      await tester.tap(find.byKey(const Key('language-setting')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('language-zh-CN')));
      await settle(tester);

      final put = api.calls('PUT', '/api/v1/users/me').single.data as Map;
      expect(put['preferredLanguage'], 'zh-CN');
      expect(find.text('设置'), findsOneWidget);
    });

    testWidgets('edit profile saves display name and bio', (tester) async {
      api.put('/api/v1/users/me', userJson(displayName: 'New Name'));
      await pumpApp(tester, api: api, location: '/settings/profile');

      await tester.enterText(find.byKey(const Key('edit-display-name')), 'New Name');
      await tester.tap(find.byKey(const Key('edit-save')));
      await settle(tester);

      final put = api.calls('PUT', '/api/v1/users/me').single.data as Map;
      expect(put['displayName'], 'New Name');
      expect(put.containsKey('username'), isFalse);
    });

    testWidgets('change email sends a verification link', (tester) async {
      api.post('/api/v1/users/me/change-email', const FakeResponse.noContent());
      await pumpApp(tester, api: api, location: '/settings/change-email');

      await tester.enterText(find.byKey(const Key('change-email-new')), 'new@example.com');
      await tester.enterText(find.byKey(const Key('change-email-password')), 'secret123');
      await tester.tap(find.byKey(const Key('change-email-submit')));
      await settle(tester);

      expect(find.text('Check your new inbox'), findsOneWidget);
    });

    testWidgets('change password emails a reset link', (tester) async {
      api.post('/api/v1/auth/forgot-password', {'message': 'ok'});
      await pumpApp(tester, api: api, location: '/settings/change-password');
      await tester.tap(find.byKey(const Key('change-password-send')));
      await settle(tester);
      expect(find.text('Reset link sent'), findsOneWidget);
    });

    testWidgets('sessions: revoke one and all others', (tester) async {
      api
        ..get('/api/v1/auth/sessions', [
          {'id': 's1', 'deviceInfo': 'Android phone', 'current': true},
          {'id': 's2', 'deviceInfo': 'Chrome on Mac', 'lastUsedAt': '2026-09-01T00:00:00Z'},
          {'id': 's3', 'deviceInfo': 'iPhone'},
        ])
        ..delete('/api/v1/auth/sessions/s2', const FakeResponse.noContent())
        ..post('/api/v1/auth/sessions/revoke-others', const FakeResponse.noContent());
      await pumpApp(tester, api: api, location: '/settings/sessions');

      expect(find.textContaining('This device'), findsOneWidget);
      await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('session-s2')),
        matching: find.text('Sign Out'),
      ));
      await settle(tester);
      expect(api.called('DELETE', '/api/v1/auth/sessions/s2'), isTrue);

      await tester.tap(find.byKey(const Key('revoke-others')));
      await settle(tester);
      expect(api.called('POST', '/api/v1/auth/sessions/revoke-others'), isTrue);
    });

    testWidgets('delete account with password signs out', (tester) async {
      api
        ..delete('/api/v1/users/me', const FakeResponse.noContent())
        ..get('/api/v1/users/me', const FakeResponse.error(401, 'UNAUTHORIZED'));
      stubDefaults(api);
      api.delete('/api/v1/users/me', const FakeResponse.noContent());
      await pumpApp(tester, api: api, location: '/settings/delete-account');

      await tester.enterText(find.byKey(const Key('delete-password')), 'secret123');
      await tester.tap(find.byKey(const Key('delete-submit')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('confirm-sheet-confirm')));
      await settle(tester);

      final del = api.calls('DELETE', '/api/v1/users/me').single.data as Map;
      expect(del, {'password': 'secret123'});
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('BGG import polls progress until done', (tester) async {
      var polls = 0;
      api
        ..post('/api/v1/users/me/bgg-import', const FakeResponse({'data': {'status': 'running'}}, status: 202))
        ..on('GET', '/api/v1/users/me/bgg-import/status', (RequestOptions _) {
          polls++;
          return FakeResponse({
            'data': polls < 3
                ? {'status': polls == 1 ? 'idle' : 'running', 'total': 10, 'processed': 4}
                : {
                    'status': 'done',
                    'total': 10,
                    'processed': 10,
                    'imported': 8,
                    'skipped': 1,
                    'failed': 1,
                    'preview': [
                      {'gameId': 'g1', 'title': 'Catan', 'thumbnailUrl': null},
                    ],
                  },
          });
        });
      await pumpApp(tester, api: api, location: '/settings/bgg-import');

      await tester.enterText(find.byKey(const Key('bgg-username')), 'meeplefan');
      await tester.tap(find.byKey(const Key('bgg-import')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Importing… 4 of 10 games'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);

      expect(find.byKey(const Key('bgg-done')), findsOneWidget);
      expect(find.text('Catan'), findsWidgets);
    });

    testWidgets('BGG username not found is shown inline', (tester) async {
      api
        ..post('/api/v1/users/me/bgg-import', const FakeResponse(null, status: 202))
        ..get('/api/v1/users/me/bgg-import/status', {
          'status': 'failed',
          'errorCode': 'BGG_USER_NOT_FOUND',
        });
      await pumpApp(tester, api: api, location: '/settings/bgg-import');
      expect(find.text('BGG username not found. Check the spelling.'), findsOneWidget);
    });

    testWidgets('biometric lock toggle and blocked users', (tester) async {
      api
        ..get('/api/v1/users/me/blocked', [summaryJson('b1', 'Bob')])
        ..delete('/api/v1/users/b1/block', const FakeResponse.noContent());
      await pumpApp(tester, api: api, location: '/settings');

      await tester.tap(find.byKey(const Key('biometric-toggle')));
      await settle(tester);
      expect(
        tester.widget<SwitchListTile>(find.byKey(const Key('biometric-toggle'))).value,
        isTrue,
      );

      await tester.tap(find.byKey(const ValueKey('settings-/settings/blocked')));
      await settle(tester);
      expect(find.text('Bob'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('unblock-b1')));
      await settle(tester);
      expect(api.called('DELETE', '/api/v1/users/b1/block'), isTrue);
    });

    testWidgets('log out returns to login', (tester) async {
      api.post('/api/v1/auth/logout', {'message': 'ok'});
      await pumpApp(tester, api: api, location: '/settings');
      await tester.tap(find.byKey(const Key('settings-sign-out')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('confirm-sheet-confirm')));
      await settle(tester);
      expect(api.called('POST', '/api/v1/auth/logout'), isTrue);
      expect(find.text('Welcome back'), findsOneWidget);
    });
  });

  group('auth', () {
    testWidgets('signed-out users land on login; Google hidden without config',
        (tester) async {
      await pumpApp(tester, api: api, signedIn: false);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byKey(const Key('google-sign-in')), findsNothing);
    });

    testWidgets('ACCOUNT_DELETED on login opens reactivation', (tester) async {
      api
        ..post('/api/v1/auth/login', const FakeResponse.error(403, 'ACCOUNT_DELETED', 'Account deleted'))
        ..post('/api/v1/auth/reactivate', _loginOk(userJson()));
      await pumpApp(tester, api: api, signedIn: false);

      await tester.enterText(find.byType(TextFormField).first, 'meeple');
      await tester.enterText(find.byType(TextFormField).last, 'secret123');
      await tester.tap(find.text('Log In'));
      await settle(tester);

      expect(find.text('Reactivate your account?'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('reactivate-password')), 'secret123');
      await tester.tap(find.byKey(const Key('reactivate-submit')));
      await settle(tester);
      final body = api.calls('POST', '/api/v1/auth/reactivate').single.data as Map;
      expect(body, {'emailOrUsername': 'meeple', 'password': 'secret123'});
    });

    testWidgets('wrong password shows the server message', (tester) async {
      api.post('/api/v1/auth/login', const FakeResponse.error(401, 'UNAUTHORIZED', 'Invalid credentials'));
      await pumpApp(tester, api: api, signedIn: false);

      await tester.enterText(find.byType(TextFormField).first, 'meeple');
      await tester.enterText(find.byType(TextFormField).last, 'nope');
      await tester.tap(find.text('Log In'));
      await settle(tester);
      expect(find.text('Invalid credentials'), findsOneWidget);
    });

    testWidgets('Google conflict is explained', (tester) async {
      api.post('/api/v1/auth/google', const FakeResponse.error(409, 'GOOGLE_ACCOUNT_CONFLICT'));
      final google = FakeGoogle(available: true, token: 'id-token');
      await pumpApp(tester, api: api, signedIn: false, google: google);

      await tester.tap(find.byKey(const Key('google-sign-in')));
      await settle(tester);

      expect((api.calls('POST', '/api/v1/auth/google').single.data as Map)['idToken'], 'id-token');
      expect(find.textContaining('already registered with a password'), findsOneWidget);
      expect(google.signOuts, 1);
    });

    testWidgets('register, forgot and reset screens render localized',
        (tester) async {
      final c = await pumpApp(tester, api: api, signedIn: false);
      await push(tester, c, '/auth/register');
      expect(find.text('Create your account'), findsOneWidget);
      await push(tester, c, '/auth/forgot-password');
      expect(find.text('Reset your password'), findsOneWidget);
      await push(tester, c, '/auth/reset-password?token=t');
      expect(find.text('Create a new password'), findsOneWidget);
      await push(tester, c, '/auth/verify-email');
      expect(find.text('Check your inbox'), findsOneWidget);
    });
  });

  group('onboarding', () {
    testWidgets('steps through profile, BGG, friends and finish',
        (tester) async {
      api
        ..get('/api/v1/users/me', userJson(onboardingCompleted: false))
        ..put('/api/v1/users/me', userJson(onboardingCompleted: false))
        ..get('/api/v1/users/suggestions', {
          'data': [summaryJson('f5', 'Sam')],
          'meta': {'page': 1, 'limit': 10, 'total': 1, 'hasMore': false},
        })
        ..get('/api/v1/users/f5/friend-status', {'status': 'NONE'})
        ..get('/api/v1/games', springPage([gameJson()]));
      await pumpApp(tester, api: api);

      expect(find.text('Track your games. Organize game nights. Build memories.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('welcome-start')));
      await settle(tester);

      expect(find.text('Set up your profile'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding-profile-continue')));
      await settle(tester);

      expect(find.text('Import from BoardGameGeek'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding-skip')));
      await settle(tester);

      expect(find.text('Sam'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding-friends-continue')));
      await settle(tester);

      expect(find.text('What do you love to play?'), findsOneWidget);
      api.put('/api/v1/users/me', userJson());
      await tester.tap(find.byKey(const Key('onboarding-finish')));
      await settle(tester);

      final last = api.calls('PUT', '/api/v1/users/me').last.data as Map;
      expect(last['onboardingCompleted'], isTrue);
      expect(find.text('Great game night'), findsOneWidget);
    });
  });
}
