// Provider logic (optimistic updates, reverts, paging, polling) against the
// fake API.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/features/events/domain/event_model.dart';
import 'package:meeple_hearth/features/events/providers/events_provider.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/features/library/providers/library_provider.dart';
import 'package:meeple_hearth/features/matching/providers/matching_provider.dart';
import 'package:meeple_hearth/features/notifications/domain/notification_model.dart';
import 'package:meeple_hearth/features/notifications/providers/notifications_provider.dart';
import 'package:meeple_hearth/features/posts/data/post_repository.dart';
import 'package:meeple_hearth/features/posts/domain/post_model.dart';
import 'package:meeple_hearth/features/posts/providers/post_provider.dart';
import 'package:meeple_hearth/features/social/domain/social_model.dart';
import 'package:meeple_hearth/features/social/providers/social_provider.dart';
import 'package:meeple_hearth/shared/models/user_summary.dart';

import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';
import '../helpers/harness.dart';

void main() {
  late FakeApi api;
  late ProviderContainer container;

  setUp(() {
    signIn();
    api = FakeApi();
    stubDefaults(api);
    container = ProviderContainer(overrides: baseOverrides(api));
    addTearDown(container.dispose);
  });

  /// Lets broadcast post-change events reach their listeners.
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  /// Keeps an auto-dispose provider alive for the test.
  void keep(ProviderListenable<Object?> provider) =>
      container.listen(provider, (_, __) {}, fireImmediately: true);

  final game = Game.fromJson(gameJson());

  group('social', () {
    test('friend status: send, accept, decline, unfriend, block, unblock',
        () async {
      api
        ..get('/api/v1/users/u1/friend-status',
            {'status': 'PENDING_RECEIVED', 'requestId': 'fr1'})
        ..post('/api/v1/users/u1/friend-request', {
          'id': 'fr2',
          'sender': summaryJson('me'),
          'receiver': summaryJson('u1'),
        })
        ..post('/api/v1/friend-requests/fr1/accept', {'id': 'fr1'})
        ..post('/api/v1/friend-requests/fr1/decline', {'id': 'fr1'})
        ..delete('/api/v1/friends/u1', const FakeResponse.noContent())
        ..post('/api/v1/users/u1/block', const FakeResponse.noContent())
        ..delete('/api/v1/users/u1/block', const FakeResponse.noContent())
        ..get('/api/v1/users/me/blocked', <Object>[]);
      final provider = friendStatusNotifierProvider('u1');
      keep(provider);
      await container.read(provider.future);
      final n = container.read(provider.notifier);

      await n.accept();
      expect(container.read(provider).value!.status, FriendshipStatus.friends);
      await n.unfriend();
      expect(container.read(provider).value!.status, FriendshipStatus.none);

      container.invalidate(provider);
      await container.read(provider.future);
      await n.decline();
      expect(container.read(provider).value!.status, FriendshipStatus.none);
      await n.accept(); // no request id → no-op
      await n.decline();

      await n.sendRequest();
      expect(container.read(provider).value!.requestId, 'fr2');
      await n.block();
      expect(container.read(provider).value!.status, FriendshipStatus.blocked);
      await n.unblock();
      expect(container.read(provider).value!.status, FriendshipStatus.none);
    });

    test('friends list paging, unfriend; requests accept/decline/cancel',
        () async {
      api
        ..get('/api/v1/friends', (RequestOptions r) => FakeResponse({
              'data': {
                'data': [
                  summaryJson(r.queryParameters['page'] == 1 ? 'f3' : 'f1'),
                ],
                'meta': {
                  'page': (r.queryParameters['page'] as int? ?? 0) + 1,
                  'limit': 30,
                  'total': 2,
                  'hasMore': r.queryParameters['page'] == null,
                },
              },
            }))
        ..delete('/api/v1/friends/f1', const FakeResponse.noContent())
        ..get('/api/v1/friend-requests/received', {
          'data': [
            {'id': 'r1', 'sender': summaryJson('s1'), 'receiver': summaryJson('me')},
            {'id': 'r2', 'sender': summaryJson('s2'), 'receiver': summaryJson('me')},
          ],
          'meta': {'page': 1, 'limit': 30, 'total': 2, 'hasMore': false},
        })
        ..get('/api/v1/friend-requests/sent', {
          'data': [
            {'id': 'r3', 'sender': summaryJson('me'), 'receiver': summaryJson('s3')},
          ],
          'meta': {'page': 1, 'limit': 30, 'total': 1, 'hasMore': false},
        })
        ..post('/api/v1/friend-requests/r1/accept', {'id': 'r1'})
        ..post('/api/v1/friend-requests/r2/decline', {'id': 'r2'})
        ..delete('/api/v1/users/s3/friend-request',
            const FakeResponse.error(404, 'REQUEST_NOT_FOUND'));

      keep(friendsListProvider);
      await container.read(friendsListProvider.future);
      await container.read(friendsListProvider.notifier).loadMore();
      expect(container.read(friendsListProvider).value!.items.map((u) => u.id),
          ['f1', 'f3']);
      await container.read(friendsListProvider.notifier).unfriend('f1');
      expect(container.read(friendsListProvider).value!.items.map((u) => u.id),
          ['f3']);

      keep(receivedRequestsProvider);
      final received = await container.read(receivedRequestsProvider.future);
      await container.read(receivedRequestsProvider.notifier).accept(received[0]);
      await container.read(receivedRequestsProvider.notifier).decline(received[1]);
      expect(container.read(receivedRequestsProvider).value, isEmpty);

      keep(sentRequestsProvider);
      final sent = await container.read(sentRequestsProvider.future);
      await container.read(sentRequestsProvider.notifier).cancel(sent.single);
      expect(container.read(sentRequestsProvider).value, isEmpty);
    });

    test('user search uses suggestions for an empty query; reports', () async {
      api
        ..get('/api/v1/users/suggestions', {
          'data': [summaryJson('s1')],
          'meta': {'page': 1, 'limit': 10, 'total': 1, 'hasMore': false},
        })
        ..get('/api/v1/users/search', {
          'data': [summaryJson('s2')],
          'meta': {'page': 1, 'limit': 20, 'total': 1, 'hasMore': false},
        })
        ..post('/api/v1/reports', const FakeResponse(null, status: 201));
      expect((await container.read(userSearchProvider(' ').future)).single.id,
          's1');
      expect((await container.read(userSearchProvider('ann').future)).single.id,
          's2');
      await container.read(reportActionsProvider).report(
            targetType: 'user',
            targetId: 's2',
            reason: ReportReason.harassment,
          );
      expect(api.calls('POST', '/api/v1/reports').single.data,
          {'targetType': 'user', 'targetId': 's2', 'reason': 'harassment'});
    });
  });

  group('posts', () {
    test('like/bookmark are optimistic and revert on failure', () async {
      api
        ..get('/api/v1/users/u1/posts', cursor([postJson()]))
        ..post('/api/v1/posts/p1/like', const FakeResponse.error(500, 'X'))
        ..post('/api/v1/posts/p1/bookmark', const FakeResponse.noContent());
      keep(userPostsProvider('u1'));
      final page = await container.read(userPostsProvider('u1').future);
      final post = page.items.single;
      final actions = container.read(postActionsProvider);

      await expectLater(actions.toggleLike(post), throwsA(isA<ServerException>()));
      await flush();
      expect(container.read(userPostsProvider('u1')).value!.items.single.likedByMe,
          isFalse);
      await actions.toggleBookmark(post);
      await flush();
      expect(
        container.read(userPostsProvider('u1')).value!.items.single.isBookmarked,
        isTrue,
      );
    });

    test('created posts are prepended to the author list; deletes remove '
        'from tagged and bookmark lists', () async {
      api
        ..get('/api/v1/users/me/posts', cursor([]))
        ..get('/api/v1/users/me/tagged-posts', cursor([postJson()], next: 't2'))
        ..get('/api/v1/users/me/bookmarks', cursor([postJson()], next: 'b2'))
        ..post('/api/v1/posts', postJson(id: 'p7', authorId: 'me'))
        ..delete('/api/v1/posts/p1', const FakeResponse.noContent())
        ..post('/api/v1/posts/p1/bookmark', const FakeResponse.noContent())
        ..delete('/api/v1/posts/p1/bookmark', const FakeResponse.noContent());
      for (final p in [
        userPostsProvider('me'),
        taggedPostsProvider('me'),
        bookmarksProvider,
      ]) {
        keep(p);
      }
      await container.read(userPostsProvider('me').future);
      await container.read(taggedPostsProvider('me').future);
      final saved = await container.read(bookmarksProvider.future);

      final actions = container.read(postActionsProvider);
      await actions.create(const PostDraft(caption: 'hi'));
      await flush();
      expect(container.read(userPostsProvider('me')).value!.items.single.id, 'p7');

      // Un-bookmarking drops the post from Saved.
      await actions.toggleBookmark(saved.items.single.copyWith(isBookmarked: true));
      await flush();
      expect(container.read(bookmarksProvider).value!.items, isEmpty);

      await actions.delete('p1');
      await flush();
      expect(container.read(taggedPostsProvider('me')).value!.items, isEmpty);

      api
        ..get('/api/v1/users/me/tagged-posts', cursor([postJson(id: 'p8')]))
        ..get('/api/v1/users/me/bookmarks', cursor([postJson(id: 'p9')]));
      await container.read(taggedPostsProvider('me').notifier).loadMore();
      expect(container.read(taggedPostsProvider('me')).value!.items.single.id,
          'p8');
      expect(api.calls('GET', '/api/v1/users/me/tagged-posts').last
          .queryParameters['cursor'], 't2');
      await container.read(bookmarksProvider.notifier).loadMore();
      expect(container.read(bookmarksProvider).value!.items.single.id, 'p9');
    });

    test('comments page by cursor and keep the post counter in step',
        () async {
      api
        ..get('/api/v1/posts/p1', postJson())
        ..get('/api/v1/posts/p1/comments', (RequestOptions r) => FakeResponse({
              'data': r.queryParameters['cursor'] == null
                  ? cursor([commentJson()], next: 'k2')
                  : cursor([commentJson(id: 'c2', authorId: 'f1')]),
            }))
        ..delete('/api/v1/posts/p1/comments/c1', const FakeResponse.noContent());
      keep(postDetailProvider('p1'));
      keep(commentsNotifierProvider('p1'));
      await container.read(postDetailProvider('p1').future);
      await container.read(commentsNotifierProvider('p1').future);
      await container.read(commentsNotifierProvider('p1').notifier).loadMore();
      final comments = container.read(commentsNotifierProvider('p1')).value!;
      expect(comments.items.map((c) => c.id), ['c1', 'c2']);
      expect(comments.hasMore, isFalse);

      await container.read(commentsNotifierProvider('p1').notifier).delete('c1');
      expect(container.read(postDetailProvider('p1')).value!.commentCount, 0);
    });

    test('event memories', () async {
      api.get('/api/v1/posts', cursor([postJson()]));
      final posts = await container.read(eventPostsProvider('e1').future);
      expect(posts.single, isA<Post>());
    });
  });

  group('library', () {
    test('setFlags adds, updates and removes; failures revert', () async {
      api
        ..put('/api/v1/users/me/games/g9', (RequestOptions r) => FakeResponse({
              'data': {
                ...userGameJson(gameId: 'g9', title: 'Root'),
                ...(r.data as Map).cast<String, dynamic>(),
              },
            }))
        ..delete('/api/v1/users/me/games/g9', const FakeResponse.noContent());
      final root = Game.fromJson(gameJson(id: 'g9', title: 'Root'));
      final n = container.read(collectionNotifierProvider.notifier);
      await container.read(collectionNotifierProvider.future);

      await n.setFlags(root, isWishlisted: true);
      final entry = container.read(collectionNotifierProvider).value!.entryFor('g9');
      expect(entry!.isWishlisted, isTrue);
      await n.setFlags(root, isOwned: false, isWishlisted: false, isFavorited: false);
      expect(container.read(collectionNotifierProvider).value!.entryFor('g9'),
          isNull);
      expect(api.called('DELETE', '/api/v1/users/me/games/g9'), isTrue);

      api.put('/api/v1/users/me/games/g9', const FakeResponse.error(500, 'X'));
      await expectLater(n.setFlags(root, isOwned: true),
          throwsA(isA<ServerException>()));
      expect(container.read(collectionNotifierProvider).value!.entryFor('g9'),
          isNull);
    });

    test('rate, remove, logPlay', () async {
      api
        ..put('/api/v1/users/me/games/g1', userGameJson())
        ..delete('/api/v1/users/me/games/g2', const FakeResponse.noContent())
        ..post('/api/v1/users/me/games/g1/plays', {'id': 'pl1'})
        ..post('/api/v1/users/me/games/g7/plays', {'id': 'pl2'});
      final n = container.read(collectionNotifierProvider.notifier);
      await container.read(collectionNotifierProvider.future);

      await n.rate(game, rating: 9, notes: 'yes');
      final put = api.calls('PUT', '/api/v1/users/me/games/g1').single.data;
      expect(put, {'personalRating': 9.0, 'notes': 'yes'});
      await n.remove('g2');
      expect(container.read(collectionNotifierProvider).value!.entryFor('g2'),
          isNull);
      await n.logPlay(game, durationMinutes: 30);
      expect(container.read(collectionNotifierProvider).value!
          .entryFor('g1')!.playCount, 4);
      await n.logPlay(Game.fromJson(gameJson(id: 'g7')));
      expect(api.called('POST', '/api/v1/users/me/games/g7/plays'), isTrue);
    });

    test('catalogue search pages; sessions page; how-to-play generate',
        () async {
      api
        ..get('/api/v1/games', (RequestOptions r) => FakeResponse({
              'data': {
                'content': [gameJson(id: 'g${r.queryParameters['page']}')],
                'page': {
                  'size': 21,
                  'number': r.queryParameters['page'],
                  'totalElements': 2,
                  'totalPages': 2,
                },
              },
            }))
        ..get('/api/v1/games/g1/sessions', cursor([postJson()], next: 's2'))
        ..get('/api/v1/games/g1/how-to-play', {'status': 'not_generated'})
        ..post('/api/v1/games/g1/how-to-play/generate', {'status': 'ready'});
      final search = gameSearchNotifierProvider('cat');
      keep(search);
      await container.read(search.future);
      await container.read(search.notifier).loadMore();
      await container.read(search.notifier).loadMore(); // last page: no-op
      expect(container.read(search).value!.content.map((g) => g.id),
          ['g0', 'g1']);

      keep(gameSessionsProvider('g1'));
      await container.read(gameSessionsProvider('g1').future);
      api.get('/api/v1/games/g1/sessions', cursor([postJson(id: 'p2')]));
      await container.read(gameSessionsProvider('g1').notifier).loadMore();
      expect(container.read(gameSessionsProvider('g1')).value!.items,
          hasLength(2));

      keep(howToPlayNotifierProvider('g1'));
      await container.read(howToPlayNotifierProvider('g1').future);
      await container.read(howToPlayNotifierProvider('g1').notifier).generate();
      expect(container.read(howToPlayNotifierProvider('g1')).value!.status,
          'ready');
    });

    test('BGG import: in-progress conflict follows the running import; other '
        'errors surface', () async {
      api
        ..get('/api/v1/users/me/bgg-import/status', {'status': 'idle'})
        ..post('/api/v1/users/me/bgg-import',
            const FakeResponse.error(409, 'BGG_IMPORT_IN_PROGRESS'));
      keep(bggImportProvider);
      await container.read(bggImportProvider.future);
      await container.read(bggImportProvider.notifier).start('alice');
      expect(container.read(bggImportProvider).value!.isRunning, isTrue);

      api.post('/api/v1/users/me/bgg-import',
          const FakeResponse.error(503, 'BGG_API_UNAVAILABLE'));
      await container.read(bggImportProvider.notifier).start('alice');
      expect(container.read(bggImportProvider).hasError, isTrue);

      api.post('/api/v1/users/me/bgg-import',
          const FakeResponse.error(409, 'OTHER'));
      await container.read(bggImportProvider.notifier).start('alice');
      expect(container.read(bggImportProvider).error, isA<ConflictException>());
    });
  });

  group('events & matching', () {
    test('event detail actions reload the event', () async {
      api
        ..get('/api/v1/events/e1', eventJson(isHost: true))
        ..post('/api/v1/events/e1/rsvp', eventJson(myRsvp: 'DECLINED'))
        ..delete('/api/v1/events/e1/rsvp', const FakeResponse.noContent())
        ..post('/api/v1/events/e1/cancel', const FakeResponse.noContent())
        ..delete('/api/v1/events/e1/participants/f1',
            const FakeResponse.noContent())
        ..post('/api/v1/events/e1/invites', eventJson())
        ..put('/api/v1/events/e1', eventJson(title: 'Renamed'))
        ..post('/api/v1/events', eventJson(id: 'e2'))
        ..get('/api/v1/events/calendar', <Object>[]);
      final p = eventDetailProvider('e1');
      keep(p);
      await container.read(p.future);
      final n = container.read(p.notifier);
      await n.rsvp('DECLINED');
      expect(container.read(p).value!.hasDeclined, isTrue);
      await n.leave();
      await n.cancel();
      await n.kick('f1');
      await n.invite(const []);
      await n.invite(const ['f2']);
      expect(api.calls('POST', '/api/v1/events/e1/invites').single.data,
          {'userIds': ['f2']});
      await n.save(EventDraft(
        title: 'Renamed',
        scheduledAt: DateTime.utc(2026, 12),
        invitedUserIds: const ['f3'],
      ));
      expect(api.calls('POST', '/api/v1/events/e1/invites'), hasLength(2));

      final created = await container.read(eventActionsProvider).create(
            EventDraft(title: 'New', scheduledAt: DateTime.utc(2026, 12)),
          );
      expect(created.id, 'e2');
      final events =
          await container.read(eventsListProvider(EventScope.past).future);
      expect(events.data, hasLength(1));
      final month =
          await container.read(calendarEventsProvider(DateTime(2026, 10)).future);
      expect(month, isEmpty);
    });

    test('match suggestions accept/dismiss (revert) and requests', () async {
      api
        ..post('/api/v1/matches/mg1/accept', eventJson(id: 'e5'))
        ..post('/api/v1/matches/mg2/dismiss', const FakeResponse.error(500, 'X'))
        ..get('/api/v1/matches/suggestions',
            [matchGroupJson(), matchGroupJson(id: 'mg2')])
        ..get('/api/v1/matches/requests/mine', <Object>[])
        ..post('/api/v1/matches/requests',
            {'id': 'mr1', 'game': gameJson(), 'status': 'ACTIVE'})
        ..delete('/api/v1/matches/requests/mr1', const FakeResponse.noContent());
      keep(matchSuggestionsProvider);
      await container.read(matchSuggestionsProvider.future);
      final event =
          await container.read(matchSuggestionsProvider.notifier).accept('mg1');
      expect(event.id, 'e5');
      await expectLater(
        container.read(matchSuggestionsProvider.notifier).dismiss('mg2'),
        throwsA(isA<ServerException>()),
      );
      expect(container.read(matchSuggestionsProvider).value!.single.id, 'mg2');

      keep(myMatchRequestsProvider);
      await container.read(myMatchRequestsProvider.future);
      await container.read(myMatchRequestsProvider.notifier).create(
            gameId: 'g1',
            availableFrom: DateTime.utc(2026, 11),
            availableTo: DateTime.utc(2026, 11, 2),
          );
      expect(container.read(myMatchRequestsProvider).value!.single.id, 'mr1');
      await container.read(myMatchRequestsProvider.notifier).cancel('mr1');
      expect(container.read(myMatchRequestsProvider).value, isEmpty);
    });
  });

  group('notifications', () {
    test('mark read (revert on failure), mark all, delete, paging', () async {
      api
        ..get('/api/v1/notifications', (RequestOptions r) => FakeResponse({
              'data': r.queryParameters['cursor'] == null
                  ? cursor([
                      notificationJson(),
                      notificationJson(id: 'n2'),
                    ], next: 'x')
                  : cursor([notificationJson(id: 'n3', read: true)]),
            }))
        ..put('/api/v1/notifications/n1/read', const FakeResponse.error(500, 'X'))
        ..put('/api/v1/notifications/read-all', const FakeResponse.noContent())
        ..delete('/api/v1/notifications/n2', const FakeResponse.noContent());
      keep(notificationsNotifierProvider);
      keep(unreadCountProvider);
      final first = await container.read(notificationsNotifierProvider.future);
      final n = container.read(notificationsNotifierProvider.notifier);
      await n.loadMore();
      expect(container.read(notificationsNotifierProvider).value!.items,
          hasLength(3));

      await expectLater(n.markRead(first.items.first),
          throwsA(isA<ServerException>()));
      expect(container.read(notificationsNotifierProvider).value!.items.first.read,
          isFalse);
      await n.markRead(AppNotification.fromJson(notificationJson(read: true)));

      await n.delete(first.items[1]);
      await n.markAllRead();
      expect(container.read(unreadCountProvider), 0);
      expect(
        container.read(notificationsNotifierProvider).value!.items.every((x) => x.read),
        isTrue,
      );
      await n.refresh();
    });

    test('preferences toggle and quiet hours save (revert on failure)',
        () async {
      api
        ..get('/api/v1/notifications/preferences', <Object>[])
        ..put('/api/v1/notifications/preferences', const FakeResponse.error(500, 'X'))
        ..get('/api/v1/notifications/settings', {'quietHoursEnabled': false})
        ..put('/api/v1/notifications/settings', const FakeResponse.noContent());
      keep(notificationPreferencesProvider);
      await container.read(notificationPreferencesProvider.future);
      await expectLater(
        container
            .read(notificationPreferencesProvider.notifier)
            .toggle('POST_LIKE', push: false),
        throwsA(isA<ServerException>()),
      );
      expect(
        container
            .read(notificationPreferencesProvider)
            .value!
            .firstWhere((p) => p.type == 'POST_LIKE')
            .pushEnabled,
        isTrue,
      );

      keep(quietHoursProvider);
      await container.read(quietHoursProvider.future);
      await container.read(quietHoursProvider.notifier).save(
            const NotificationSettings(
              quietHoursEnabled: true,
              quietHoursStart: '22:00',
              quietHoursEnd: '07:00',
            ),
          );
      expect(container.read(quietHoursProvider).value!.quietHoursEnabled, isTrue);
    });
  });

  test('UserSummary JSON round trip keeps friendship status', () {
    const u = UserSummary(id: 'a', friendshipStatus: FriendshipStatus.pendingSent);
    expect(UserSummary.fromJson(u.toJson()).friendshipStatus,
        FriendshipStatus.pendingSent);
  });
}
