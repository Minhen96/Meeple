import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';
import '../helpers/harness.dart';

FakeHandler _signedIn(Map<String, dynamic> user) =>
    (RequestOptions _) => FakeResponse.signedIn({'data': user});

void main() {
  late FakeApi api;

  setUp(() {
    api = FakeApi();
    stubDefaults(api);
  });

  group('comments', () {
    testWidgets('post author may delete any comment; deleted authors render '
        'as Deleted User', (tester) async {
      api
        ..get('/api/v1/posts/p9', postJson(id: 'p9', authorId: 'me'))
        ..get('/api/v1/posts/p9/comments', cursor([
          commentJson(id: 'c5', authorId: 'f1'),
          {
            'id': 'c6',
            'authorId': null,
            'authorUsername': null,
            'authorDisplayName': null,
            'authorAvatarUrl': null,
            'body': 'ghost words',
            'createdAt': DateTime.now().toUtc().toIso8601String(),
          },
        ]))
        ..delete('/api/v1/posts/p9/comments/c5', const FakeResponse.noContent());
      await pumpApp(tester, api: api, location: '/posts/p9');

      expect(find.textContaining('Deleted User', findRichText: true),
          findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('comment-menu-c5')));
      await settle(tester);
      expect(find.byKey(const Key('comment-edit')), findsNothing);
      expect(find.byKey(const Key('comment-report')), findsOneWidget);
      await tester.tap(find.byKey(const Key('comment-delete')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('confirm-sheet-confirm')));
      await settle(tester);
      expect(api.called('DELETE', '/api/v1/posts/p9/comments/c5'), isTrue);
    });

    testWidgets("others' comments on others' posts cannot be deleted",
        (tester) async {
      api
        ..get('/api/v1/posts/p1', postJson())
        ..get('/api/v1/posts/p1/comments',
            cursor([commentJson(id: 'c2', authorId: 'f1')]));
      await pumpApp(tester, api: api, location: '/posts/p1');

      await tester.tap(find.byKey(const ValueKey('comment-menu-c2')));
      await settle(tester);
      expect(find.byKey(const Key('comment-delete')), findsNothing);
    });
  });

  group('account', () {
    testWidgets('Google-only accounts: no change-email entry and DELETE '
        'confirmation is preselected', (tester) async {
      stubDefaults(api, me: {...userJson(), 'hasPassword': false});
      api.delete('/api/v1/users/me', const FakeResponse.noContent());
      final container =
          await pumpApp(tester, api: api, location: '/settings');

      expect(find.text('Change Email'), findsNothing);

      await push(tester, container, '/settings/delete-account');
      expect(find.byKey(const Key('delete-passwordless')), findsNothing);
      expect(find.byKey(const Key('delete-password')), findsNothing);
      await tester.enterText(find.byKey(const Key('delete-confirm')), 'DELETE');
      await tester.tap(find.byKey(const Key('delete-submit')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('confirm-sheet-confirm')));
      await settle(tester);

      expect(api.calls('DELETE', '/api/v1/users/me').single.data,
          {'confirm': 'DELETE'});
    });

    testWidgets('password accounts confirm with the password only',
        (tester) async {
      stubDefaults(api, me: {...userJson(), 'hasPassword': true});
      await pumpApp(tester, api: api, location: '/settings/delete-account');
      expect(find.byKey(const Key('delete-passwordless')), findsNothing);
      expect(find.byKey(const Key('delete-password')), findsOneWidget);
    });

    testWidgets('sessions requests identify this device by its refresh cookie',
        (tester) async {
      api
        ..get('/api/v1/auth/sessions', [
          {'id': 's1', 'deviceInfo': 'Android phone', 'current': true},
          {'id': 's2', 'deviceInfo': 'Chrome on Mac'},
        ])
        ..post(
          '/api/v1/auth/sessions/revoke-others',
          const FakeResponse(
            {'data': {'revoked': 1}},
            headers: {
              'set-cookie': ['access_token=fresh; Path=/; HttpOnly'],
            },
          ),
        );
      await pumpApp(tester, api: api, location: '/settings/sessions');

      expect(api.calls('GET', '/api/v1/auth/sessions').last.headers['Cookie'],
          'refresh_token=r');
      await tester.tap(find.byKey(const Key('revoke-others')));
      await settle(tester);
      expect(
        api
            .calls('POST', '/api/v1/auth/sessions/revoke-others')
            .single
            .headers['Cookie'],
        'refresh_token=r',
      );
      expect(find.text('Chrome on Mac'), findsNothing);
    });
  });

  group('reactivation', () {
    testWidgets('Google sign-in into a deleted account offers Google '
        'reactivation', (tester) async {
      api
        ..post(
          '/api/v1/auth/google',
          const FakeResponse.error(403, 'ACCOUNT_DELETED', 'Scheduled'),
        )
        ..post('/api/v1/auth/reactivate', _signedIn(userJson()));
      final google = FakeGoogle(available: true, token: 'gid');
      await pumpApp(tester, api: api, signedIn: false, google: google);

      await tester.tap(find.byKey(const Key('google-sign-in')));
      await settle(tester);
      expect(find.text('Reactivate your account?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('reactivate-google')));
      await settle(tester);
      expect(api.calls('POST', '/api/v1/auth/reactivate').single.data,
          {'googleIdToken': 'gid'});
      expect(find.text('Welcome back! Your account has been restored.'),
          findsOneWidget);
    });

    testWidgets('a failed Google reactivation signs Google out and explains',
        (tester) async {
      api
        ..post(
          '/api/v1/auth/google',
          const FakeResponse.error(403, 'ACCOUNT_DELETED', 'Scheduled'),
        )
        ..post(
          '/api/v1/auth/reactivate',
          const FakeResponse.error(401, 'GOOGLE_REAUTH_REQUIRED', 'Sign in again'),
        );
      final google = FakeGoogle(available: true, token: 'gid');
      await pumpApp(tester, api: api, signedIn: false, google: google);

      await tester.tap(find.byKey(const Key('google-sign-in')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('reactivate-google')));
      await settle(tester);
      expect(google.signOuts, 2);
      expect(find.text('Reactivate your account?'), findsOneWidget);
    });

    testWidgets('cancelling the Google prompt does nothing', (tester) async {
      api.post(
        '/api/v1/auth/login',
        const FakeResponse.error(403, 'ACCOUNT_DELETED', 'Scheduled'),
      );
      final google = FakeGoogle(available: true);
      await pumpApp(tester, api: api, signedIn: false, google: google);

      await tester.enterText(find.byType(TextFormField).first, 'meeple');
      await tester.enterText(find.byType(TextFormField).last, 'secret123');
      await tester.tap(find.text('Log In'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('reactivate-google')));
      await settle(tester);
      expect(api.called('POST', '/api/v1/auth/reactivate'), isFalse);
    });
  });
}
