// Every repository call checked against the backend controllers: method,
// path, query, body and response parsing (incl. deleted-user null safety).

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/auth_session.dart';
import 'package:meeple_hearth/core/storage/secure_storage.dart';
import 'package:meeple_hearth/features/auth/data/auth_remote_data_source.dart';
import 'package:meeple_hearth/features/auth/domain/user_model.dart';
import 'package:meeple_hearth/features/events/data/event_repository.dart';
import 'package:meeple_hearth/features/events/domain/event_model.dart';
import 'package:meeple_hearth/features/home/data/feed_repository.dart';
import 'package:meeple_hearth/features/home/domain/feed_item_model.dart';
import 'package:meeple_hearth/features/library/data/collection_repository.dart';
import 'package:meeple_hearth/features/library/data/game_repository.dart';
import 'package:meeple_hearth/features/library/domain/user_game_model.dart';
import 'package:meeple_hearth/features/matching/data/match_repository.dart';
import 'package:meeple_hearth/features/notifications/data/notification_repository.dart';
import 'package:meeple_hearth/features/notifications/domain/notification_model.dart';
import 'package:meeple_hearth/features/posts/data/post_repository.dart';
import 'package:meeple_hearth/features/posts/domain/post_model.dart';
import 'package:meeple_hearth/features/profile/data/user_repository.dart';
import 'package:meeple_hearth/features/search/data/search_repository.dart';
import 'package:meeple_hearth/features/settings/data/account_repository.dart';
import 'package:meeple_hearth/features/social/data/social_repository.dart';
import 'package:meeple_hearth/shared/models/cursor_page.dart';
import 'package:meeple_hearth/shared/models/user_summary.dart';

import 'helpers/fake_api.dart';
import 'helpers/fixtures.dart';

Map<String, dynamic> _page(List<Object?> items, {bool hasMore = false}) => {
      'data': items,
      'meta': {'page': 1, 'limit': 20, 'total': items.length, 'hasMore': hasMore},
    };

void main() {
  late FakeApi api;

  setUp(() => api = FakeApi());

  Map<String, dynamic> query(String method, String path) =>
      api.calls(method, path).last.queryParameters;
  Object? body(String method, String path) => api.calls(method, path).last.data;

  group('feed', () {
    test('GET /feed with cursor + limit; kinds post, activity, unknown', () async {
      final repo = FeedRepository(api.dio());
      api.get('/api/v1/feed', cursor([
        {'kind': 'post', 'createdAt': '2026-09-01T10:00:00Z', 'post': postJson()},
        {
          'kind': 'activity',
          'createdAt': '2026-09-01T09:00:00Z',
          'activity': {
            'id': 'a1',
            'type': 'event_joined',
            'user': null,
            'data': {'eventId': 'e1', 'eventTitle': 'Catan Night'},
          },
        },
        {'kind': 'story', 'createdAt': '2026-09-01T08:00:00Z'},
      ], next: 'n1'));

      final page = await repo.getFeed(cursor: 'c0');
      expect(query('GET', '/api/v1/feed'), {'limit': 20, 'size': 20, 'cursor': 'c0'});
      expect(page.items[0], isA<FeedPostItem>());
      final activity = (page.items[1] as FeedActivityItem).activity;
      expect(activity.user.deleted, isTrue);
      expect(activity.user.id, '');
      expect(activity.eventTitle, 'Catan Night');
      expect(page.items[2], isA<FeedUnknownItem>());
      expect(page.nextCursor, 'n1');
      expect(page.hasMore, isTrue);
    });

    test('a legacy page of bare posts is wrapped as post items', () async {
      api.get('/api/v1/feed', FakeResponse(_page([postJson()], hasMore: true)));
      final page = await FeedRepository(api.dio()).getFeed();
      expect((page.items.single as FeedPostItem).post.id, 'p1');
      expect(CursorPage.legacyPageOf(page.nextCursor), 1);
    });
  });

  group('posts', () {
    late PostRepository repo;
    setUp(() => repo = PostRepository(api.dio()));

    test('create / update (clearGame) / get / delete', () async {
      api
        ..post('/api/v1/posts', postJson())
        ..put('/api/v1/posts/p1', postJson(caption: 'edited'))
        ..get('/api/v1/posts/p1', postJson())
        ..delete('/api/v1/posts/p1', const FakeResponse.noContent());

      await repo.createPost(
        PostDraft(
          caption: 'hi',
          playedAt: DateTime.utc(2026, 9, 1),
          gameId: 'g1',
          eventId: 'e1',
          taggedUserIds: const ['f1'],
          imageKeys: const ['uploads/me/x.jpg'],
        ),
      );
      expect(body('POST', '/api/v1/posts'), {
        'caption': 'hi',
        'playedAt': '2026-09-01T00:00:00.000Z',
        'gameId': 'g1',
        'eventId': 'e1',
        'taggedUserIds': ['f1'],
        'imageKeys': ['uploads/me/x.jpg'],
      });

      final edited =
          await repo.updatePost('p1', const PostDraft(caption: '', location: ''));
      expect(edited.caption, 'edited');
      expect(body('PUT', '/api/v1/posts/p1'), {
        'caption': '',
        'location': '',
        'clearGame': true,
        'taggedUserIds': <String>[],
      });
      await repo.updatePost('p1', const PostDraft(caption: 'x', gameId: 'g2'));
      final update = body('PUT', '/api/v1/posts/p1')! as Map;
      expect(update['gameId'], 'g2');
      expect(update.containsKey('clearGame'), isFalse);
      expect(update.containsKey('eventId'), isFalse);

      expect((await repo.getPost('p1')).id, 'p1');
      await repo.deletePost('p1');
      expect(api.called('DELETE', '/api/v1/posts/p1'), isTrue);
    });

    test('likes and bookmarks', () async {
      for (final m in ['POST', 'DELETE']) {
        api
          ..on(m, '/api/v1/posts/p1/like', const FakeResponse.noContent())
          ..on(m, '/api/v1/posts/p1/bookmark', const FakeResponse.noContent());
      }
      await repo.likePost('p1');
      await repo.unlikePost('p1');
      await repo.bookmarkPost('p1');
      await repo.unbookmarkPost('p1');
      for (final m in ['POST', 'DELETE']) {
        expect(api.called(m, '/api/v1/posts/p1/like'), isTrue);
        expect(api.called(m, '/api/v1/posts/p1/bookmark'), isTrue);
      }
    });

    test('cursor lists: bookmarks, tagged, event memories, game sessions',
        () async {
      api
        ..get('/api/v1/users/me/bookmarks', cursor([postJson()]))
        ..get('/api/v1/users/u1/tagged-posts', cursor([postJson()], next: 'n'))
        ..get('/api/v1/posts', cursor([postJson()]))
        ..get('/api/v1/games/g1/sessions', cursor([postJson()]));

      expect((await repo.getBookmarks()).items, hasLength(1));
      final tagged = await repo.getTaggedPosts('u1', cursor: 'abc');
      expect(tagged.nextCursor, 'n');
      expect(query('GET', '/api/v1/users/u1/tagged-posts')['cursor'], 'abc');
      await repo.getEventPosts('e1');
      expect(query('GET', '/api/v1/posts')['eventId'], 'e1');
      await repo.getGameSessions('g1');
      expect(api.called('GET', '/api/v1/games/g1/sessions'), isTrue);
    });

    test('user posts follow the offset page with page/size only', () async {
      api.get('/api/v1/users/u1/posts', FakeResponse(_page([postJson()], hasMore: true)));
      final first = await repo.getUserPosts('u1');
      expect(query('GET', '/api/v1/users/u1/posts'), {'limit': 20, 'size': 20});
      await repo.getUserPosts('u1', cursor: first.nextCursor);
      expect(query('GET', '/api/v1/users/u1/posts'), {'page': 1, 'size': 20});
    });

    test('tagged posts of a gone user → NotFoundException', () async {
      api.get(
        '/api/v1/users/x/tagged-posts',
        const FakeResponse.error(404, 'USER_NOT_FOUND'),
      );
      await expectLater(
        repo.getTaggedPosts('x'),
        throwsA(isA<NotFoundException>()
            .having((e) => e.code, 'code', 'USER_NOT_FOUND')),
      );
    });

    test('comments: cursor page and legacy page shapes', () async {
      api.get('/api/v1/posts/p1/comments', cursor([commentJson()], next: 'k1'));
      final page = await repo.getComments('p1');
      expect(page.nextCursor, 'k1');
      expect(query('GET', '/api/v1/posts/p1/comments').containsKey('page'),
          isFalse);
      await repo.getComments('p1', cursor: 'k1');
      expect(query('GET', '/api/v1/posts/p1/comments')['cursor'], 'k1');

      api.get('/api/v1/posts/p1/comments',
          FakeResponse(_page([commentJson()], hasMore: true)));
      final legacy = await repo.getComments('p1');
      expect(legacy.nextCursor, 'page:1');
      await repo.getComments('p1', cursor: legacy.nextCursor);
      expect(query('GET', '/api/v1/posts/p1/comments'), {'page': 1, 'size': 20});
    });

    test('comment add / edit / delete', () async {
      api
        ..post('/api/v1/posts/p1/comments', commentJson())
        ..put('/api/v1/posts/p1/comments/c1', commentJson())
        ..delete('/api/v1/posts/p1/comments/c1', const FakeResponse.noContent());
      await repo.addComment('p1', 'Nice!');
      expect(body('POST', '/api/v1/posts/p1/comments'), {'body': 'Nice!'});
      await repo.updateComment('p1', 'c1', 'Edited');
      expect(body('PUT', '/api/v1/posts/p1/comments/c1'), {'body': 'Edited'});
      await repo.deleteComment('p1', 'c1');
      expect(api.called('DELETE', '/api/v1/posts/p1/comments/c1'), isTrue);
    });

    test('expired edit window surfaces as Forbidden EDIT_WINDOW_EXPIRED',
        () async {
      api.put('/api/v1/posts/p1',
          const FakeResponse.error(403, 'EDIT_WINDOW_EXPIRED'));
      await expectLater(
        repo.updatePost('p1', const PostDraft(caption: 'x')),
        throwsA(isA<ForbiddenException>()
            .having((e) => e.code, 'code', 'EDIT_WINDOW_EXPIRED')),
      );
    });
  });

  group('deleted users are null-safe', () {
    test('post author null or deleted', () {
      final gone = Post.fromJson({...postJson(), 'author': null});
      expect(gone.author.deleted, isTrue);
      final soft = Post.fromJson({
        ...postJson(),
        'author': {'id': 'u9', 'username': null, 'displayName': null,
          'avatarUrl': null, 'deleted': true},
      });
      expect(soft.author.id, 'u9');
      expect(soft.author.deleted, isTrue);
      expect(soft.author.displayName, '');
    });

    test('comment with flat, nested and missing author', () {
      final flat = Comment.fromJson({
        ...commentJson(),
        'authorDisplayName': 'Mia',
      });
      expect(flat.authorDeleted, isFalse);
      expect(flat.author.displayName, 'Mia');

      final nested = Comment.fromJson({
        'id': 'c2',
        'author': {'id': 'u2', 'username': 'bo', 'displayName': 'Bo',
          'avatarUrl': 'https://a', 'deleted': false},
        'body': 'hey',
        'createdAt': '2026-01-01T00:00:00Z',
      });
      expect(nested.authorId, 'u2');
      expect(nested.authorUsername, 'bo');
      expect(nested.authorAvatarUrl, 'https://a');
      expect(nested.author.displayName, 'Bo');

      final nestedDeleted = Comment.fromJson({
        'id': 'c3',
        'author': {'id': 'u3', 'deleted': true},
        'body': 'x',
        'createdAt': '2026-01-01T00:00:00Z',
      });
      expect(nestedDeleted.authorDeleted, isTrue);

      final hardDeleted = Comment.fromJson({
        'id': 'c4',
        'authorId': null,
        'authorUsername': null,
        'body': 'x',
        'createdAt': '2026-01-01T00:00:00Z',
      });
      expect(hardDeleted.authorDeleted, isTrue);
      expect(hardDeleted.author.username, '');

      final roundTrip = Comment.fromJson(hardDeleted.toJson());
      expect(roundTrip.authorDeleted, isTrue);
    });

    test('event host as deleted UserSummary; summary without id', () {
      final event = Event.fromJson({
        ...eventJson(),
        'host': {'id': 'h1', 'deleted': true},
      });
      expect(event.host!.deleted, isTrue);
      expect(UserSummary.fromJson(const {'username': 'x'}).deleted, isTrue);
    });

    test('hard-deleted placeholders use the all-zero id', () {
      const zero = '00000000-0000-0000-0000-000000000000';
      final host = Event.fromJson({
        ...eventJson(),
        'host': {'id': zero, 'username': null, 'displayName': null,
          'avatarUrl': null, 'deleted': false},
      }).host!;
      expect(host.deleted, isTrue);

      final comment = Comment.fromJson({
        'id': 'c9',
        'authorId': zero,
        'authorUsername': null,
        'authorDisplayName': null,
        'authorAvatarUrl': null,
        'author': {'id': zero, 'username': null, 'displayName': null,
          'avatarUrl': null, 'deleted': true},
        'body': 'x',
        'createdAt': '2026-01-01T00:00:00Z',
      });
      expect(comment.authorDeleted, isTrue);
      expect(comment.author.deleted, isTrue);

      final softDeleted = Comment.fromJson({
        'id': 'c10',
        'authorId': 'u7',
        'author': {'id': 'u7', 'deleted': true},
        'body': 'x',
        'createdAt': '2026-01-01T00:00:00Z',
      });
      expect(softDeleted.authorDeleted, isTrue);

      final n = AppNotification.fromJson({
        ...notificationJson(path: null),
        'actor': {'id': zero, 'deleted': true},
      });
      expect(n.path, isNull);
      final byRef = AppNotification.fromJson({
        ...notificationJson(path: null),
        'actor': null,
        'referenceId': zero,
      });
      expect(byRef.path, isNull);
      final live = AppNotification.fromJson({
        ...notificationJson(path: null),
        'actor': null,
      });
      expect(live.path, '/profile/f1');
    });

    test('UserSummaryWithStatus and SuggestedUser parse', () {
      final s = UserSummary.fromJson({
        ...summaryJson('u1', 'Ann'),
        'friendshipStatus': 'pending_received',
      });
      expect(s.friendshipStatus, FriendshipStatus.pendingReceived);
      final suggested = UserSummary.fromJson(const {
        'id': 'u2', 'username': 'bo', 'displayName': null, 'avatarUrl': null,
        'sharedGames': 3,
      });
      expect(suggested.displayName, 'bo');
      expect(suggested.friendshipStatus, FriendshipStatus.none);
    });
  });

  group('social', () {
    late SocialRepository repo;
    setUp(() => repo = SocialRepository(api.dio()));

    test('friend requests and friendship', () async {
      api
        ..get('/api/v1/users/u1/friend-status',
            {'status': 'PENDING_RECEIVED', 'requestId': 'fr1'})
        ..post('/api/v1/users/u1/friend-request', {
          'id': 'fr2',
          'sender': userJson(),
          'receiver': userJson(id: 'u1'),
          'status': 'PENDING',
          'createdAt': '2026-01-01T00:00:00Z',
        })
        ..delete('/api/v1/users/u1/friend-request', const FakeResponse.noContent())
        ..post('/api/v1/friend-requests/fr1/accept', {'id': 'fr1'})
        ..post('/api/v1/friend-requests/fr1/decline', {'id': 'fr1'})
        ..get('/api/v1/friend-requests/received', FakeResponse(_page([])))
        ..get('/api/v1/friend-requests/sent', FakeResponse(_page([])))
        ..get('/api/v1/friends', FakeResponse(_page([userJson(id: 'f1')])))
        ..delete('/api/v1/friends/f1', const FakeResponse.noContent())
        ..post('/api/v1/users/u1/block', const FakeResponse.noContent())
        ..delete('/api/v1/users/u1/block', const FakeResponse.noContent());

      final status = await repo.getFriendStatus('u1');
      expect(status.status, FriendshipStatus.pendingReceived);
      expect(status.requestId, 'fr1');
      final sent = await repo.sendFriendRequest('u1');
      expect(sent.receiver.id, 'u1');
      await repo.cancelFriendRequest('u1');
      expect(api.called('DELETE', '/api/v1/users/u1/friend-request'), isTrue);
      await repo.acceptRequest('fr1');
      await repo.declineRequest('fr1');
      await repo.getReceivedRequests();
      await repo.getSentRequests();
      expect((await repo.getFriends()).items.single.id, 'f1');
      expect(query('GET', '/api/v1/friends')['size'], 30);
      await repo.unfriend('f1');
      await repo.block('u1');
      await repo.unblock('u1');
      expect(api.called('DELETE', '/api/v1/users/u1/block'), isTrue);
    });

    test('blocked list, search, suggestions and reports', () async {
      api
        ..get('/api/v1/users/me/blocked', [summaryJson('b1', 'Bad')])
        ..get('/api/v1/users/search', FakeResponse(_page([
          {...summaryJson('u1', 'Ann'), 'friendshipStatus': 'friends'},
        ])))
        ..get('/api/v1/users/suggestions', FakeResponse(_page([userJson(id: 'u2')])))
        ..post('/api/v1/reports', const FakeResponse(null, status: 201));

      expect((await repo.getBlocked()).single.id, 'b1');
      final found = await repo.searchUsers('ann');
      expect(found.single.friendshipStatus, FriendshipStatus.friends);
      expect(query('GET', '/api/v1/users/search'), {'q': 'ann', 'size': 20});
      expect((await repo.getSuggestions()).single.id, 'u2');
      expect(query('GET', '/api/v1/users/suggestions'), {'size': 10});
      await repo.report(targetType: 'comment', targetId: 'c1', reason: 'spam');
      expect(body('POST', '/api/v1/reports'),
          {'targetType': 'comment', 'targetId': 'c1', 'reason': 'spam'});
    });

    test('blocked list errors are not swallowed', () async {
      api.get('/api/v1/users/me/blocked', const FakeResponse.error(500, 'X'));
      await expectLater(repo.getBlocked(), throwsA(isA<ServerException>()));
    });

    test('report limit → RateLimitException', () async {
      api.post('/api/v1/reports',
          const FakeResponse.error(429, 'REPORT_LIMIT_EXCEEDED'));
      await expectLater(
        repo.report(targetType: 'user', targetId: 'u1', reason: 'spam'),
        throwsA(isA<RateLimitException>()),
      );
    });
  });

  group('account', () {
    late AuthSessionManager session;
    late AccountRepository repo;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({
        'auth_session':
            '{"accessToken":"a1","refreshToken":"r1","userId":"me"}',
      });
      session = AuthSessionManager(SecureStorage());
      repo = AccountRepository(api.dio(), session);
    });

    test('DELETE /users/me with password or confirm', () async {
      api.delete('/api/v1/users/me', const FakeResponse.noContent());
      await repo.deleteAccount(password: 'pw');
      expect(body('DELETE', '/api/v1/users/me'), {'password': 'pw'});
      await repo.deleteAccount(confirm: 'DELETE');
      expect(body('DELETE', '/api/v1/users/me'), {'confirm': 'DELETE'});
    });

    test('change email, password reset and export', () async {
      api
        ..post('/api/v1/users/me/change-email', {'message': 'sent'})
        ..post('/api/v1/auth/forgot-password', {'message': 'sent'})
        ..post('/api/v1/users/me/export',
            const FakeResponse({'data': {'id': 'x', 'status': 'PENDING'}},
                status: 202));
      await repo.changeEmail(currentPassword: 'pw', newEmail: 'n@x.io');
      expect(body('POST', '/api/v1/users/me/change-email'),
          {'currentPassword': 'pw', 'newEmail': 'n@x.io'});
      await repo.sendPasswordReset('me@x.io');
      await repo.requestExport();
      expect(api.called('POST', '/api/v1/users/me/export'), isTrue);
    });

    test('sessions carry the refresh cookie; revoke-others stores the new '
        'access token', () async {
      api
        ..get('/api/v1/auth/sessions', [
          {
            'id': 's1',
            'deviceInfo': 'Pixel',
            'createdAt': '2026-01-01T00:00:00Z',
            'lastUsedAt': '2026-01-02T00:00:00Z',
            'current': true,
          },
        ])
        ..delete('/api/v1/auth/sessions/s2', const FakeResponse.noContent())
        ..post(
          '/api/v1/auth/sessions/revoke-others',
          const FakeResponse(
            {'data': {'revoked': 2}},
            headers: {
              'set-cookie': ['access_token=a2; Path=/; HttpOnly'],
            },
          ),
        );

      final sessions = await repo.getSessions();
      expect(sessions.single.current, isTrue);
      expect(api.calls('GET', '/api/v1/auth/sessions').single.headers['Cookie'],
          'refresh_token=r1');
      await repo.revokeSession('s2');
      expect(
        api.calls('DELETE', '/api/v1/auth/sessions/s2').single.headers['Cookie'],
        'refresh_token=r1',
      );
      expect(await repo.revokeOtherSessions(), 2);
      expect(await session.currentAccessToken(), 'a2');
      expect(await session.refreshToken(), 'r1');
    });

    test('signed out: no cookie and no token write', () async {
      FlutterSecureStorage.setMockInitialValues({});
      api.post('/api/v1/auth/sessions/revoke-others',
          const FakeResponse({'data': {'revoked': 0}}));
      expect(await session.sessionCookieHeader(), isEmpty);
      expect(await repo.revokeOtherSessions(), 0);
      await session.replaceAccessToken('zzz');
      expect(await session.currentAccessToken(), isNull);
    });
  });

  group('auth', () {
    test('reactivate with password or Google ID token', () async {
      api.post('/api/v1/auth/reactivate', const FakeResponse.signedIn({
        'data': {'id': 'me', 'username': 'meeple', 'displayName': 'Mia',
          'avatarUrl': null, 'email': 'm@x.io', 'onboardingCompleted': true},
      }));
      final remote = AuthRemoteDataSource(api.dio());
      await remote.reactivate(emailOrUsername: 'meeple', password: 'pw');
      expect(body('POST', '/api/v1/auth/reactivate'),
          {'emailOrUsername': 'meeple', 'password': 'pw'});
      final result = await remote.reactivateWithGoogle(idToken: 'gid');
      expect(body('POST', '/api/v1/auth/reactivate'), {'googleIdToken': 'gid'});
      expect(result.tokens.refreshToken, 'r2');
    });

    test('UserProfileResponse self fields', () {
      final user = _selfUser();
      expect(user.hasPassword, isFalse);
      expect(user.googleLinked, isTrue);
      expect(user.usernameChangeAvailableAt, isNotNull);
    });
  });

  group('profile', () {
    test('GET/PUT /users/me, /users/{id}, stats', () async {
      final repo = UserRepository(api.dio());
      api
        ..get('/api/v1/users/me', userJson())
        ..put('/api/v1/users/me', userJson(displayName: 'New'))
        ..get('/api/v1/users/u1', userJson(id: 'u1'))
        ..get('/api/v1/users/u1/stats', {
          'gamesOwned': 3,
          'sessions': 4,
          'friends': 5,
          'mostPlayedGame': null,
          'favoriteCategory': null,
          'mostPlayedWith': {'userId': 'f1', 'displayName': 'Fred',
            'sharedSessions': 2},
          'totalPlayMinutes': 90,
        });
      expect((await repo.getMe()).id, 'me');
      final updated = await repo.updateMe(const ProfileUpdate(
        displayName: 'New',
        username: 'new_name',
        bio: 'b',
        location: 'l',
        avatarUrl: 'https://a',
        preferredLanguage: 'zh-CN',
        timezone: 'Asia/Kuala_Lumpur',
        onboardingCompleted: true,
      ));
      expect(updated.displayName, 'New');
      expect((body('PUT', '/api/v1/users/me')! as Map).keys, containsAll(<String>[
        'displayName', 'username', 'bio', 'location', 'avatarUrl',
        'preferredLanguage', 'timezone', 'onboardingCompleted',
      ]));
      expect((await repo.getUser('u1')).id, 'u1');
      final stats = await repo.getStats('u1');
      expect(stats.mostPlayedWith!.sharedSessions, 2);
    });

    test('stats errors propagate (no silent zeros)', () async {
      api.get('/api/v1/users/u1/stats', const FakeResponse.error(404, 'USER_NOT_FOUND'));
      await expectLater(
        UserRepository(api.dio()).getStats('u1'),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('library', () {
    test('collection, plays and BGG import', () async {
      final repo = CollectionRepository(api.dio());
      api
        ..get('/api/v1/users/me/games', [userGameJson()])
        ..get('/api/v1/users/u1/games', [userGameJson()])
        ..put('/api/v1/users/me/games/g1', userGameJson())
        ..delete('/api/v1/users/me/games/g1', const FakeResponse.noContent())
        ..post('/api/v1/users/me/games/g1/plays', {
          'id': 'pl1', 'gameId': 'g1', 'playedAt': '2026-01-01T00:00:00Z',
          'notes': null, 'durationMinutes': 60, 'playerCount': 4, 'postId': null,
        })
        ..get('/api/v1/users/me/games/g1/plays', [
          {'id': 'pl1', 'gameId': 'g1', 'playedAt': '2026-01-01T00:00:00Z',
            'durationMinutes': 60, 'playerCount': 4, 'postId': null},
        ])
        ..delete('/api/v1/users/me/plays/pl1', const FakeResponse.noContent())
        ..post('/api/v1/users/me/bgg-import',
            const FakeResponse({'data': {'status': 'running'}}, status: 202))
        ..get('/api/v1/users/me/bgg-import/status', {
          'status': 'done', 'total': 2, 'processed': 2, 'imported': 1,
          'skipped': 1, 'failed': 0, 'errorCode': null,
          'preview': [{'gameId': 'g1', 'title': 'Catan', 'thumbnailUrl': null}],
        });

      await repo.getMyCollection(filter: CollectionFilter.wishlisted);
      expect(query('GET', '/api/v1/users/me/games'), {'filter': 'wishlisted'});
      await repo.getUserCollection('u1');
      expect(query('GET', '/api/v1/users/u1/games'), {'filter': 'owned'});
      await repo.upsertUserGame(gameId: 'g1', isOwned: true, personalRating: 0);
      expect(body('PUT', '/api/v1/users/me/games/g1'),
          {'isOwned': true, 'personalRating': 0.0});
      await repo.removeFromCollection('g1');
      await repo.logPlay('g1',
          playedAt: DateTime.utc(2026), notes: 'fun', durationMinutes: 60,
          playerCount: 4);
      expect(body('POST', '/api/v1/users/me/games/g1/plays'), {
        'playedAt': '2026-01-01T00:00:00.000Z',
        'notes': 'fun',
        'durationMinutes': 60,
        'playerCount': 4,
      });
      expect((await repo.getPlays('g1')).single.durationMinutes, 60);
      await repo.deletePlay('pl1');
      await repo.startBggImport('alice');
      expect(body('POST', '/api/v1/users/me/bgg-import'), {'bggUsername': 'alice'});
      final status = await repo.getBggImportStatus();
      expect(status.isDone, isTrue);
      expect(status.preview.single.title, 'Catan');
    });

    test('logPlay no longer falls back to log-play on 404', () async {
      api.post('/api/v1/users/me/games/g1/plays',
          const FakeResponse.error(404, 'GAME_NOT_FOUND'));
      await expectLater(
        CollectionRepository(api.dio()).logPlay('g1'),
        throwsA(isA<NotFoundException>()),
      );
      expect(api.called('POST', '/api/v1/users/me/games/g1/log-play'), isFalse);
    });

    test('game friends and reviews (deleted users tolerated)', () async {
      final repo = GameRepository(api.dio());
      api
        ..get('/api/v1/games/g1/friends', [
          {'user': summaryJson('f1', 'Fred'), 'playCount': 2,
            'personalRating': 7.5, 'isOwned': true},
        ])
        ..get('/api/v1/games/g1/reviews', [
          {'user': null, 'personalRating': 9, 'notes': 'great', 'playCount': 1},
        ]);
      expect((await repo.getFriends('g1')).single.isOwned, isTrue);
      final review = (await repo.getReviews('g1')).single;
      expect(review.user.deleted, isTrue);
      expect(review.personalRating, 9);
    });
  });

  group('events', () {
    late EventRepository repo;
    setUp(() => repo = EventRepository(api.dio()));

    test('scoped lists and calendar', () async {
      api
        ..get('/api/v1/events', [eventJson()])
        ..get('/api/v1/events/calendar', [eventJson()]);
      for (final scope in EventScope.values) {
        await repo.getEvents(scope);
        expect(query('GET', '/api/v1/events'), {'scope': scope.wire, 'limit': 50});
      }
      await repo.getCalendar(DateTime.utc(2026, 10), DateTime.utc(2026, 11));
      expect(query('GET', '/api/v1/events/calendar'), {
        'from': '2026-10-01T00:00:00.000Z',
        'to': '2026-11-01T00:00:00.000Z',
      });
      expect(api.called('GET', '/api/v1/events/me'), isFalse);
    });

    test('rsvp sends status as a query parameter only', () async {
      api.post('/api/v1/events/e1/rsvp', eventJson());
      await repo.rsvp('e1', 'ACCEPTED');
      final call = api.calls('POST', '/api/v1/events/e1/rsvp').single;
      expect(call.queryParameters, {'status': 'ACCEPTED'});
      expect(call.data, isNull);
    });

    test('calendar range errors propagate', () async {
      api.get('/api/v1/events/calendar',
          const FakeResponse.error(400, 'INVALID_RANGE'));
      await expectLater(
        repo.getCalendar(DateTime.utc(2026), DateTime.utc(2026, 6)),
        throwsA(isA<BadRequestException>()),
      );
    });
  });

  group('notifications', () {
    late NotificationRepository repo;
    setUp(() => repo = NotificationRepository(api.dio()));

    test('preferences are completed with defaults; settings parsed', () async {
      api
        ..get('/api/v1/notifications/preferences', [
          {'type': 'POST_LIKE', 'inAppEnabled': false, 'pushEnabled': false},
        ])
        ..get('/api/v1/notifications/settings', {
          'quietHoursEnabled': true,
          'quietHoursStart': '22:00',
          'quietHoursEnd': '07:00',
          'timezone': 'UTC',
        });
      final prefs = await repo.getPreferences();
      expect(prefs, hasLength(notificationTypes.length));
      expect(prefs.firstWhere((p) => p.type == 'POST_LIKE').pushEnabled, isFalse);
      expect(prefs.firstWhere((p) => p.type == 'EVENT_INVITE').pushEnabled, isTrue);
      final settings = await repo.getSettings();
      expect(settings.quietHoursStart, '22:00');
    });

    test('preference errors propagate instead of faking defaults', () async {
      api.get('/api/v1/notifications/preferences',
          const FakeResponse.error(500, 'X'));
      await expectLater(repo.getPreferences(), throwsA(isA<ServerException>()));
    });

    test('cursor listing and deleted actor', () async {
      api.get('/api/v1/notifications', cursor([
        {...notificationJson(), 'actor': {'id': 'x', 'deleted': true}},
      ]));
      final page = await repo.getNotifications();
      expect(query('GET', '/api/v1/notifications'), {'limit': 30, 'size': 30});
      expect(page.items.single.actor!.deleted, isTrue);
    });
  });

  group('search & matching', () {
    test('GET /search?type=', () async {
      api.get('/api/v1/search', {
        'games': <Object>[],
        'users': [summaryJson('u1', 'Ann')],
        'events': [
          {'id': 'e1', 'title': 'Night', 'scheduledAt': '2026-12-01T18:00:00Z',
            'status': 'OPEN', 'visibility': 'PUBLIC',
            'game': {'id': 'g1', 'title': 'Catan', 'thumbnailUrl': null}},
        ],
      });
      final results = await SearchRepository(api.dio())
          .search('ann', limit: 10, type: SearchType.users);
      expect(query('GET', '/api/v1/search'),
          {'q': 'ann', 'limit': 10, 'type': 'users'});
      expect(results.users.single.id, 'u1');
      expect(results.events.single.game!.name, 'Catan');
      expect(results.isEmpty, isFalse);
    });

    test('match requests use /requests/mine', () async {
      api.get('/api/v1/matches/requests/mine', [
        {'id': 'mr1', 'game': gameJson(), 'status': 'ACTIVE'},
      ]);
      final mine = await MatchRepository(api.dio()).getMyRequests();
      expect(mine.single.id, 'mr1');
      expect(api.called('GET', '/api/v1/matches/requests/me'), isFalse);
    });
  });
}

User _selfUser() => User.fromJson({
      ...userJson(),
      'timezone': 'Asia/Kuala_Lumpur',
      'bggUsername': null,
      'usernameChangeAvailableAt': '2026-11-01T00:00:00Z',
      'hasPassword': false,
      'googleLinked': true,
    });
