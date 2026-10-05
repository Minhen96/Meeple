import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/connectivity_service.dart';
import 'package:meeple_hearth/core/storage/cache_store.dart';
import 'package:meeple_hearth/features/library/data/collection_repository.dart';
import 'package:meeple_hearth/features/library/data/game_repository.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/features/library/domain/user_game_model.dart';
import 'package:meeple_hearth/features/posts/data/post_repository.dart';
import 'package:meeple_hearth/features/posts/domain/post_model.dart';
import 'package:meeple_hearth/shared/models/pagination_model.dart';
import 'package:meeple_hearth/shared/models/paged_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'library_provider.g.dart';

/// The viewer's whole collection (owned + wishlisted + favourited).
final class CollectionState {
  const CollectionState(this.items, {this.cachedAt});

  final List<UserGame> items;
  final DateTime? cachedAt;

  /// Entries for a library tab, alphabetical (SCREENS §5.3).
  List<UserGame> filtered(CollectionFilter filter) =>
      items.where((g) => g.matches(filter)).toList()
        ..sort(
          (a, b) =>
              a.game.name.toLowerCase().compareTo(b.game.name.toLowerCase()),
        );

  UserGame? entryFor(String gameId) {
    for (final g in items) {
      if (g.gameId == gameId) return g;
    }
    return null;
  }

  CollectionState withEntry(UserGame entry) => CollectionState(
        [
          for (final g in items)
            if (g.gameId != entry.gameId) g,
          if (entry.isOwned || entry.isWishlisted || entry.isFavorited) entry,
        ],
        cachedAt: cachedAt,
      );

  CollectionState without(String gameId) => CollectionState(
        items.where((g) => g.gameId != gameId).toList(),
        cachedAt: cachedAt,
      );
}

/// `GET /users/me/games?filter=all`, cached for 24 h (MOBILE_FLUTTER §6).
/// Tabs are derived client-side from the multi-boolean flags.
@Riverpod(keepAlive: true)
class CollectionNotifier extends _$CollectionNotifier {
  @override
  Future<CollectionState> build() => _load();

  Future<CollectionState> _load() async {
    final result = await readThrough<List<UserGame>>(
      cache: ref.read(cacheStoreProvider),
      key: CacheKeys.collection(CollectionFilter.all.wire),
      maxAge: CacheTtl.collection,
      fetch: () => ref.read(collectionRepositoryProvider).getMyCollection(),
      encode: (items) => items.map((g) => g.toJson()).toList(),
      decode: (json) => (json as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(UserGame.fromJson)
          .toList(),
    );
    return CollectionState(result.data, cachedAt: result.cachedAt);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_load);
  }

  CollectionState get _current =>
      state.valueOrNull ?? const CollectionState([]);

  /// Toggles collection flags. All three false removes the entry (an
  /// all-false row is invalid — FEATURES §3.1). Optimistic, reverted on
  /// failure.
  Future<void> setFlags(
    Game game, {
    bool? isOwned,
    bool? isWishlisted,
    bool? isFavorited,
  }) async {
    ensureOnline(ref);
    final before = _current;
    final existing = before.entryFor(game.id);
    final next = (existing ??
            UserGame(id: 'pending-${game.id}', gameId: game.id, game: game))
        .copyWith(
      isOwned: isOwned ?? existing?.isOwned ?? false,
      isWishlisted: isWishlisted ?? existing?.isWishlisted ?? false,
      isFavorited: isFavorited ?? existing?.isFavorited ?? false,
    );
    state = AsyncValue.data(before.withEntry(next));
    final repo = ref.read(collectionRepositoryProvider);
    try {
      if (!next.isOwned && !next.isWishlisted && !next.isFavorited) {
        if (existing != null) await repo.removeFromCollection(game.id);
        return;
      }
      final saved = await repo.upsertUserGame(
        gameId: game.id,
        isOwned: next.isOwned,
        isWishlisted: next.isWishlisted,
        isFavorited: next.isFavorited,
      );
      state = AsyncValue.data(
        saved.id == null ? _current.without(game.id) : _current.withEntry(saved),
      );
    } catch (_) {
      state = AsyncValue.data(before);
      rethrow;
    }
  }

  /// Personal rating (1–10) and notes.
  Future<void> rate(Game game, {double? rating, String? notes}) async {
    ensureOnline(ref);
    final saved = await ref.read(collectionRepositoryProvider).upsertUserGame(
          gameId: game.id,
          personalRating: rating,
          notes: notes,
          // Rating a game you don't track yet adds it as played/owned.
          isOwned: _current.entryFor(game.id) == null ? true : null,
        );
    state = AsyncValue.data(_current.withEntry(saved));
  }

  Future<void> remove(String gameId) async {
    ensureOnline(ref);
    await ref.read(collectionRepositoryProvider).removeFromCollection(gameId);
    state = AsyncValue.data(_current.without(gameId));
  }

  /// Logs a play and bumps the local play count.
  Future<void> logPlay(
    Game game, {
    DateTime? playedAt,
    String? notes,
    int? durationMinutes,
    int? playerCount,
  }) async {
    ensureOnline(ref);
    await ref.read(collectionRepositoryProvider).logPlay(
          game.id,
          playedAt: playedAt,
          notes: notes,
          durationMinutes: durationMinutes,
          playerCount: playerCount,
        );
    final existing = _current.entryFor(game.id);
    if (existing != null) {
      state = AsyncValue.data(
        _current.withEntry(existing.copyWith(playCount: existing.playCount + 1)),
      );
    } else {
      // The backend creates the entry on first play; fetch it.
      unawaited(refresh());
    }
    ref.invalidate(gamePlaysProvider(game.id));
  }
}

/// Browse / search the game catalogue (page-based Spring page).
@riverpod
class GameSearchNotifier extends _$GameSearchNotifier {
  static const _pageSize = 21;

  @override
  Future<PaginatedResult<Game>> build(String query) =>
      ref.read(gameRepositoryProvider).searchGames(
            query: query,
            params: const PageParams(size: _pageSize),
          );

  bool _loading = false;

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || _loading) return;
    _loading = true;
    try {
      final next = await ref.read(gameRepositoryProvider).searchGames(
            query: query,
            params: PageParams(page: current.page + 1, size: _pageSize),
          );
      state = AsyncValue.data(
        PaginatedResult(
          content: [...current.content, ...next.content],
          page: next.page,
          size: next.size,
          totalElements: next.totalElements,
          totalPages: next.totalPages,
          last: next.last,
        ),
      );
    } finally {
      _loading = false;
    }
  }
}

/// Game detail, cached for 7 days.
@riverpod
Future<CachedResult<Game>> gameDetail(Ref ref, String gameId) =>
    readThrough<Game>(
      cache: ref.read(cacheStoreProvider),
      key: CacheKeys.gameDetail(gameId),
      maxAge: CacheTtl.gameDetail,
      fetch: () => ref.read(gameRepositoryProvider).getGame(gameId),
      encode: (g) => g.toJson(),
      decode: (json) => Game.fromJson(json! as Map<String, dynamic>),
    );

@riverpod
Future<List<FriendGameEntry>> gameFriends(Ref ref, String gameId) =>
    ref.read(gameRepositoryProvider).getFriends(gameId);

@riverpod
Future<List<GameReview>> gameReviews(Ref ref, String gameId) =>
    ref.read(gameRepositoryProvider).getReviews(gameId);

@riverpod
Future<List<PlayLog>> gamePlays(Ref ref, String gameId) =>
    ref.read(collectionRepositoryProvider).getPlays(gameId);

/// Posts tagged with a game (Sessions tab).
@riverpod
class GameSessions extends _$GameSessions {
  @override
  Future<PagedState<Post>> build(String gameId) async => PagedState.fromPage(
        await ref.read(postRepositoryProvider).getGameSessions(gameId),
      );

  Future<void> loadMore() => loadNextPage<Post>(
        current: state.valueOrNull,
        read: () => state.valueOrNull,
        emit: (s) => state = AsyncValue.data(s),
        fetch: (cursor) => ref
            .read(postRepositoryProvider)
            .getGameSessions(gameId, cursor: cursor),
      );
}

/// How-to-Play guide; polls every 3 s while it is being generated.
@riverpod
class HowToPlayNotifier extends _$HowToPlayNotifier {
  Timer? _poll;

  @override
  Future<HowToPlay> build(String gameId) async {
    ref.onDispose(() => _poll?.cancel());
    final guide = await ref.read(gameRepositoryProvider).getHowToPlay(gameId);
    _schedulePoll(guide);
    return guide;
  }

  void _schedulePoll(HowToPlay guide) {
    _poll?.cancel();
    if (guide.status != 'generating') return;
    _poll = Timer(const Duration(seconds: 3), () async {
      try {
        final next =
            await ref.read(gameRepositoryProvider).getHowToPlay(gameId);
        state = AsyncValue.data(next);
        _schedulePoll(next);
      } catch (e, st) {
        state = AsyncValue.error(e, st);
      }
    });
  }

  Future<void> generate() async {
    ensureOnline(ref);
    final guide =
        await ref.read(gameRepositoryProvider).generateHowToPlay(gameId);
    state = AsyncValue.data(guide);
    _schedulePoll(guide);
  }
}

/// BGG collection import with 2 s progress polling (SCREENS §3.4).
@riverpod
class BggImport extends _$BggImport {
  Timer? _poll;

  static const pollInterval = Duration(seconds: 2);

  @override
  Future<BggImportStatus> build() async {
    ref.onDispose(() => _poll?.cancel());
    try {
      final status =
          await ref.read(collectionRepositoryProvider).getBggImportStatus();
      if (status.isRunning) _schedulePoll();
      return status;
    } catch (_) {
      return const BggImportStatus();
    }
  }

  Future<void> start(String bggUsername) async {
    ensureOnline(ref);
    state = const AsyncValue.data(BggImportStatus(status: 'running'));
    try {
      await ref.read(collectionRepositoryProvider).startBggImport(bggUsername);
      _schedulePoll();
    } on ConflictException catch (e, st) {
      // 409 BGG_IMPORT_IN_PROGRESS: an import is already running — follow it.
      if (e.code == 'BGG_IMPORT_IN_PROGRESS') {
        _schedulePoll();
      } else {
        state = AsyncValue.error(e, st);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _schedulePoll() {
    _poll?.cancel();
    _poll = Timer(pollInterval, () async {
      try {
        final status =
            await ref.read(collectionRepositoryProvider).getBggImportStatus();
        state = AsyncValue.data(status);
        if (status.isRunning) {
          _schedulePoll();
        } else if (status.isDone) {
          unawaited(ref.read(collectionNotifierProvider.notifier).refresh());
        }
      } catch (e, st) {
        state = AsyncValue.error(e, st);
      }
    });
  }
}
