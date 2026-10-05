import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeple_hearth/core/locale/locale_provider.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/storage/cache_store.dart';
import 'package:meeple_hearth/core/utils/app_date_utils.dart';
import 'package:meeple_hearth/features/ai/data/ai_repository.dart';
import 'package:meeple_hearth/features/ai/providers/ai_chat_provider.dart';
import 'package:meeple_hearth/features/events/domain/event_model.dart';
import 'package:meeple_hearth/features/home/data/feed_repository.dart';
import 'package:meeple_hearth/features/home/domain/feed_item_model.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/features/library/domain/user_game_model.dart';
import 'package:meeple_hearth/features/library/presentation/library_screen.dart';
import 'package:meeple_hearth/features/library/presentation/widgets/how_to_play_section.dart';
import 'package:meeple_hearth/features/notifications/domain/notification_model.dart';
import 'package:meeple_hearth/features/notifications/presentation/notification_prefs_screen.dart';
import 'package:meeple_hearth/features/notifications/presentation/notification_text.dart';
import 'package:meeple_hearth/features/notifications/presentation/notifications_screen.dart';
import 'package:meeple_hearth/firebase_options.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/models/cursor_page.dart';
import 'package:meeple_hearth/shared/models/paged_state.dart';
import 'package:meeple_hearth/shared/models/user_summary.dart';

import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final en = lookupAppLocalizations(const Locale('en'));
  final zh = lookupAppLocalizations(const Locale('zh'));

  group('CursorPage', () {
    test('parses the cursor contract and the legacy page shape', () {
      final c = CursorPage.fromJson(cursor([summaryJson('a')], next: 'x'), UserSummary.fromJson);
      expect(c.items.single.id, 'a');
      expect(c.nextCursor, 'x');
      expect(CursorPage.query('x', 20), {'limit': 20, 'size': 20, 'cursor': 'x'});

      final legacy = CursorPage.fromJson({
        'data': [summaryJson('b')],
        'meta': {'page': 1, 'limit': 20, 'total': 40, 'hasMore': true},
      }, UserSummary.fromJson);
      expect(legacy.hasMore, isTrue);
      expect(CursorPage.legacyPageOf(legacy.nextCursor), 1);
      expect(CursorPage.query(legacy.nextCursor, 20)['page'], 1);

      expect(CursorPage.fromJson([summaryJson('c')], UserSummary.fromJson).items, hasLength(1));
      expect(CursorPage.fromJson('nope', UserSummary.fromJson).items, isEmpty);
      expect(CursorPage.fromJson({'x': 1}, UserSummary.fromJson).items, isEmpty);
      final merged = c.append(legacy);
      expect(merged.items, hasLength(2));
      expect(merged.copyWithItems([]).items, isEmpty);
      expect(c.toJson((u) => u.toJson())['nextCursor'], 'x');
    });
  });

  group('PagedState', () {
    test('loadNextPage appends and records failures', () async {
      var state = PagedState<int>.fromPage(
        const CursorPage(items: [1], nextCursor: 'n', hasMore: true),
      );
      await loadNextPage<int>(
        current: state,
        read: () => state,
        emit: (s) => state = s,
        fetch: (_) async => const CursorPage(items: [2]),
      );
      expect(state.items, [1, 2]);
      expect(state.canLoadMore, isFalse);

      state = state.copyWith(hasMore: true, nextCursor: 'm');
      await loadNextPage<int>(
        current: state,
        read: () => state,
        emit: (s) => state = s,
        fetch: (_) async => throw const NetworkException(),
      );
      expect(state.loadMoreError, isA<NetworkException>());
      expect(state.mapItems((i) => i == 1, (_) => 9).items, [9, 2]);
      expect(state.removeWhere((i) => i == 2).items, [1]);
    });
  });

  group('readThrough cache', () {
    test('falls back to cached data only on connectivity failures', () async {
      final cache = MemoryCacheStore();
      final ok = await readThrough<List<int>>(
        cache: cache,
        key: 'k',
        maxAge: const Duration(hours: 1),
        fetch: () async => [1, 2],
        encode: (v) => v,
        decode: (j) => (j! as List).cast<int>(),
      );
      expect(ok.isFromCache, isFalse);

      final offline = await readThrough<List<int>>(
        cache: cache,
        key: 'k',
        maxAge: const Duration(hours: 1),
        fetch: () async => throw const NetworkException(),
        encode: (v) => v,
        decode: (j) => (j! as List).cast<int>(),
      );
      expect(offline.data, [1, 2]);
      expect(offline.cachedAt, isNotNull);

      expect(
        () => readThrough<List<int>>(
          cache: cache,
          key: 'k',
          maxAge: const Duration(hours: 1),
          fetch: () async => throw const ServerException(),
          encode: (v) => v,
          decode: (j) => (j! as List).cast<int>(),
        ),
        throwsA(isA<ServerException>()),
      );
      expect(
        () => readThrough<List<int>>(
          cache: cache,
          key: 'other',
          maxAge: const Duration(hours: 1),
          fetch: () async => throw const TimeoutException(),
          encode: (v) => v,
          decode: (j) => (j! as List).cast<int>(),
        ),
        throwsA(isA<TimeoutException>()),
      );
      await cache.remove('k');
      expect(await cache.read('k'), isNull);
      await cache.write('z', {'a': 1});
      await cache.clear();
      expect(await cache.read('z'), isNull);
      expect(
        CachedValue(null, DateTime(2000)).isOlderThan(const Duration(days: 1)),
        isTrue,
      );
    });
  });

  group('models', () {
    test('feed items: post, activity, unknown and legacy bare posts', () {
      final post = FeedRepository.parseFeedItem(postJson());
      expect(post, isA<FeedPostItem>());
      final activity = FeedRepository.parseFeedItem({
        'kind': 'activity',
        'createdAt': '2026-01-01T00:00:00Z',
        'activity': {
          'id': 'a',
          'type': 'event_joined',
          'user': summaryJson('u'),
          'data': {'eventId': 'e1', 'eventTitle': 'Night'},
        },
      }) as FeedActivityItem;
      expect(activity.activity.eventId, 'e1');
      expect(activity.activity.eventTitle, 'Night');
      expect(
        FeedRepository.parseFeedItem({'kind': 'story', 'createdAt': null}),
        isA<FeedUnknownItem>(),
      );
    });

    test('UserSummary friendship statuses and display name fallback', () {
      for (final (raw, s) in [
        ('PENDING_SENT', FriendshipStatus.pendingSent),
        ('pending_received', FriendshipStatus.pendingReceived),
        ('FRIENDS', FriendshipStatus.friends),
        ('BLOCKED', FriendshipStatus.blocked),
        (null, FriendshipStatus.none),
      ]) {
        expect(FriendshipStatus.parse(raw), s);
        final u = UserSummary(id: 'x', friendshipStatus: s);
        expect(UserSummary.fromJson(u.toJson()).friendshipStatus, s);
      }
      expect(
        UserSummary.fromJson({'id': 'x', 'username': 'bob', 'displayName': ''})
            .displayName,
        'bob',
      );
    });

    test('event helpers and draft request', () {
      final e = Event.fromJson(eventJson(status: 'OPEN'));
      expect(e.isAttending, isTrue);
      expect(e.isFull, isFalse);
      expect(e.displayLocation, 'Cafe');
      expect(e.visibilityValue, EventVisibility.friends);
      expect(e.acceptedParticipants.single.asUser.id, 'f1');
      expect(EventVisibility.parse('nope'), EventVisibility.inviteOnly);
      final req = EventDraft(
        title: 'T',
        scheduledAt: DateTime.utc(2030),
        invitedUserIds: const ['a'],
        location: '',
      ).toRequest();
      expect(req['invitedUserIds'], ['a']);
      expect(req.containsKey('location'), isFalse);
      expect(req['visibility'], 'INVITE_ONLY');
      final past = Event.fromJson(eventJson(at: DateTime(2000)));
      expect(past.isCompleted, isTrue);
    });

    test('collection filters and game helpers', () {
      final g = UserGame.fromJson(userGameJson(owned: false, wishlisted: true));
      expect(g.matches(CollectionFilter.wishlisted), isTrue);
      expect(g.matches(CollectionFilter.owned), isFalse);
      expect(g.matches(CollectionFilter.all), isTrue);
      final game = Game.fromJson(gameJson());
      expect(game.playersLabel, '3–4');
      expect(game.copyWith(maxPlayers: 3).playersLabel, '3');
      expect(game.copyWith(maxPlayers: null).playersLabel, '3+');
      expect(game.copyWith(minPlayers: null, maxPlayers: null).playersLabel, isNull);
      expect(
        gameMatchesFilters(game, players: PlayerFilter.four, duration: DurationFilter.from1to2h, weight: WeightFilter.medium),
        isTrue,
      );
      expect(gameMatchesFilters(game, duration: DurationFilter.under30), isFalse);
      expect(gameMatchesFilters(game, weight: WeightFilter.heavy), isFalse);
      expect(LibraryScreen.tabIndexOf('favorites'), 3);
      expect(LibraryScreen.tabIndexOf(null), 0);
      final removed = UserGame.fromJson({...userGameJson(), 'id': null});
      expect(removed.id, isNull);
      expect(
        BggImportStatus.fromJson({
          'status': 'done',
          'preview': [{'gameId': 'g', 'title': 'T'}],
        }).preview.single.title,
        'T',
      );
    });

    test('how-to-play flattening', () {
      expect(flattenGuideValue('  '), isEmpty);
      expect(flattenGuideValue(3), ['3']);
      expect(flattenGuideValue({'exists': false, 'x': 'y'}), isEmpty);
      expect(
        flattenGuideValue([
          {'name': 'Trade', 'effect': 'swap'},
          {'question': 'Q?', 'answer': 'A'},
          {'details': 'only'},
          'tip',
        ]),
        ['• Trade: swap', '• Q?: A', '• only', '• tip'],
      );
    });
  });

  group('l10n', () {
    test('every notification type has text in both languages', () {
      for (final type in notificationTypes) {
        final n = AppNotification(
          id: 'n',
          type: type,
          data: const {'eventTitle': 'Night', 'gameName': 'Catan', 'count': 3},
          createdAt: DateTime(2026),
        );
        expect(notificationText(en, n), isNotEmpty);
        expect(notificationText(zh, n), isNotEmpty);
        expect(notificationTypeLabel(en, type), isNot(type));
      }
      expect(
        notificationText(
          en,
          AppNotification(id: 'n', type: 'X', title: 'Server', createdAt: DateTime(2026)),
        ),
        'Server',
      );
    });

    test('localizedError maps codes and exception types', () {
      expect(localizedError(en, const ConflictException('x', code: 'GOOGLE_ACCOUNT_CONFLICT')),
          contains('registered with a password'));
      expect(localizedError(zh, const NetworkException()), zh.errorNetwork);
      expect(localizedError(en, const NotFoundException()), en.errorNotFound);
      expect(localizedError(en, const ForbiddenException()), en.errorForbidden);
      expect(localizedError(en, const RateLimitException()), en.errorRateLimit);
      expect(localizedError(en, const ServiceUnavailableException()), en.errorServiceUnavailable);
      expect(localizedError(en, const ServerException()), en.errorServer);
      expect(localizedError(en, const TimeoutException()), en.errorTimeout);
      expect(localizedError(en, const OfflineException()), en.errorOffline);
      expect(localizedError(en, const UnauthorizedException()), en.errorSessionExpired);
      expect(localizedError(en, const BadRequestException('Server says')), 'Server says');
      expect(localizedError(en, StateError('x')), en.errorGeneric);
    });

    test('dates and grouping', () {
      final now = DateTime(2026, 5, 10, 12);
      expect(AppDateUtils.timeAgo(now, en, now: now), 'just now');
      expect(AppDateUtils.timeAgo(now.subtract(const Duration(minutes: 5)), en, now: now), '5m ago');
      expect(AppDateUtils.timeAgo(now.subtract(const Duration(hours: 3)), en, now: now), '3h ago');
      expect(AppDateUtils.timeAgo(now.subtract(const Duration(days: 1)), en, now: now), 'yesterday');
      expect(AppDateUtils.timeAgo(now.subtract(const Duration(days: 4)), zh, now: now), '4 天前');
      expect(AppDateUtils.timeAgo(DateTime(2026, 1, 2), en, now: now), contains('2026'));
      expect(AppDateUtils.formatHhMm(7, 5), '07:05');
      expect(AppDateUtils.isSameDay(now, now.add(const Duration(hours: 1))), isTrue);
      expect(AppDateUtils.formatMonthShort(now), 'MAY');
      expect(AppDateUtils.formatMonthYear(now), contains('2026'));
      expect(AppDateUtils.formatDayMonth(now), contains('10'));
      expect(AppDateUtils.isToday(now, now: now), isTrue);
      expect(groupOf(now, now: now), NotificationGroup.today);
      expect(groupOf(now.subtract(const Duration(days: 2)), now: now), NotificationGroup.thisWeek);
      expect(groupOf(now.subtract(const Duration(days: 20)), now: now), NotificationGroup.earlier);
      expect(parseHhMm('22:30'), const TimeOfDay(hour: 22, minute: 30));
      expect(parseHhMm('99:00'), isNull);
      expect(parseHhMm(null), isNull);
      expect(parseHhMm('x'), isNull);
    });

    test('language mapping', () {
      expect(AppLanguage.fromWire('zh-CN'), AppLanguage.zhCN);
      expect(AppLanguage.fromWire('zh_cn'), AppLanguage.zhCN);
      expect(AppLanguage.fromWire('en'), AppLanguage.en);
      expect(AppLanguage.fromWire(null), AppLanguage.en);
    });
  });

  test('firebase options need every value for the platform', () {
    expect(DefaultFirebaseOptions.currentPlatform, isNull);
    expect(
      DefaultFirebaseOptions.forPlatform(
        TargetPlatform.android,
        apiKey: 'k',
        projectId: 'p',
        senderId: 's',
        androidAppId: '1:2:android:3',
      )!.appId,
      '1:2:android:3',
    );
    final ios = DefaultFirebaseOptions.forPlatform(
      TargetPlatform.iOS,
      apiKey: 'k',
      projectId: 'p',
      senderId: 's',
      iosAppId: '1:2:ios:3',
      storageBucket: 'b',
    )!;
    expect(ios.iosBundleId, 'com.meeplehearth.meeple');
    expect(ios.storageBucket, 'b');
    expect(
      DefaultFirebaseOptions.forPlatform(TargetPlatform.android, apiKey: 'k'),
      isNull,
    );
    expect(DefaultFirebaseOptions.forPlatform(null, apiKey: 'k'), isNull);
  });

  group('AI chat', () {
    test('keeps the transcript and sends only the last 3 pairs', () async {
      final api = FakeApi();
      var n = 0;
      api.on('POST', '/api/v1/ai/rules', (_) {
        n++;
        if (n == 2) return const FakeResponse.error(500, 'AI_ERROR');
        return FakeResponse({'data': {'answer': 'A$n'}});
      });
      final container = ProviderContainer(overrides: [
        aiRepositoryProvider.overrideWithValue(AiRepository(api.dio())),
      ]);
      addTearDown(container.dispose);
      final sub = container.listen(aiChatProvider('g1'), (_, __) {});
      final chat = container.read(aiChatProvider('g1').notifier);

      await chat.ask('Q1');
      await chat.ask('Q2');
      expect(container.read(aiChatProvider('g1'))[1].error, isA<ServerException>());
      await chat.retry(1);
      for (var i = 3; i <= 5; i++) {
        await chat.ask('Q$i');
      }
      await chat.ask('   ');
      final msgs = container.read(aiChatProvider('g1'));
      expect(msgs.map((m) => m.question), ['Q1', 'Q2', 'Q3', 'Q4', 'Q5']);
      expect(chat.history.map((t) => t.question), ['Q3', 'Q4', 'Q5']);
      final last = api.calls('POST', '/api/v1/ai/rules').last.data as Map;
      expect((last['conversationHistory'] as List).length, 3);
      chat.clear();
      expect(container.read(aiChatProvider('g1')), isEmpty);
      sub.close();
    });
  });
}
