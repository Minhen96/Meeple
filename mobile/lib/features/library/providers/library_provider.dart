import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/connectivity_service.dart';
import 'package:meeple_hearth/core/storage/cache_store.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
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
  Future<CollectionState> build() {
    // Another account signed in (or out): drop the previous collection.
    ref.watch(authUserIdProvider);
    return _load();
  }

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
///
/// Transient poll failures keep the last guide and retry with backoff; only a
/// 401/403/404 ends polling with an error.
@riverpod
class HowToPlayNotifier extends _$HowToPlayNotifier {
  static const pollInterval = Duration(seconds: 3);

  final _poller = _Poller();

  @override
  Future<HowToPlay> build(String gameId) async {
    final generation = _poller.attach(ref);
    final guide = await ref.read(gameRepositoryProvider).getHowToPlay(gameId);
    if (_poller.isCurrent(generation)) _schedulePoll(guide);
    return guide;
  }

  void _schedulePoll(HowToPlay guide) {
    if (guide.status != 'generating') {
      _poller.cancel();
      return;
    }
    _poller.schedule(
      pollInterval,
      fetch: () => ref.read(gameRepositoryProvider).getHowToPlay(gameId),
      onData: (HowToPlay next) {
        state = AsyncValue.data(next);
        _schedulePoll(next);
      },
      onTerminalError: (e, st) => state = AsyncValue.error(e, st),
    );
  }

  Future<void> generate() async {
    ensureOnline(ref);
    final generation = _poller.generation;
    final guide =
        await ref.read(gameRepositoryProvider).generateHowToPlay(gameId);
    if (!_poller.isCurrent(generation)) return;
    state = AsyncValue.data(guide);
    _schedulePoll(guide);
  }
}

/// BGG collection import with 2 s progress polling (SCREENS §3.4).
///
/// Polling stops on a terminal status (`done`/`failed`/`idle`) or a
/// 401/403/404; transient failures keep the last status and retry with
/// backoff.
@riverpod
class BggImport extends _$BggImport {
  static const pollInterval = Duration(seconds: 2);

  final _poller = _Poller();

  @override
  Future<BggImportStatus> build() async {
    final generation = _poller.attach(ref);
    try {
      final status =
          await ref.read(collectionRepositoryProvider).getBggImportStatus();
      if (status.isRunning && _poller.isCurrent(generation)) _schedulePoll();
      return status;
    } catch (_) {
      return const BggImportStatus();
    }
  }

  Future<void> start(String bggUsername) async {
    ensureOnline(ref);
    final generation = _poller.generation;
    state = const AsyncValue.data(BggImportStatus(status: 'running'));
    try {
      await ref.read(collectionRepositoryProvider).startBggImport(bggUsername);
      if (_poller.isCurrent(generation)) _schedulePoll();
    } on ConflictException catch (e, st) {
      if (!_poller.isCurrent(generation)) return;
      // 409 BGG_IMPORT_IN_PROGRESS: an import is already running — follow it.
      if (e.code == 'BGG_IMPORT_IN_PROGRESS') {
        _schedulePoll();
      } else {
        state = AsyncValue.error(e, st);
      }
    } catch (e, st) {
      if (_poller.isCurrent(generation)) state = AsyncValue.error(e, st);
    }
  }

  void _schedulePoll() => _poller.schedule(
        pollInterval,
        fetch: () =>
            ref.read(collectionRepositoryProvider).getBggImportStatus(),
        onData: (BggImportStatus status) {
          state = AsyncValue.data(status);
          if (status.isRunning) {
            _schedulePoll();
          } else if (status.isDone) {
            unawaited(
              ref.read(collectionNotifierProvider.notifier).refresh(),
            );
          }
        },
        onTerminalError: (e, st) => state = AsyncValue.error(e, st),
      );
}

/// Single-timer poller bound to a notifier's lifetime.
///
/// Every dispose (provider disposed or rebuilt) bumps [generation], so a
/// response that arrives afterwards is dropped instead of writing the state
/// of a dead notifier. Failures other than 401/403/404 are treated as
/// transient: the poll is retried with exponential backoff.
final class _Poller {
  static const maxBackoff = Duration(seconds: 30);

  Timer? _timer;
  int generation = 0;
  int _failures = 0;

  /// Call at the start of `build`; returns the generation of this build.
  int attach(Ref ref) {
    ref.onDispose(() {
      generation++;
      cancel();
    });
    _failures = 0;
    return generation;
  }

  bool isCurrent(int gen) => gen == generation;

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void schedule<T>(
    Duration interval, {
    required Future<T> Function() fetch,
    required void Function(T value) onData,
    required void Function(Object error, StackTrace stackTrace)
        onTerminalError,
  }) {
    cancel();
    final gen = generation;
    _timer = Timer(backoff(interval, _failures), () async {
      try {
        final value = await fetch();
        if (!isCurrent(gen)) return;
        _failures = 0;
        onData(value);
      } catch (e, st) {
        if (!isCurrent(gen)) return;
        if (isTerminalPollError(e)) {
          onTerminalError(e, st);
          return;
        }
        _failures++;
        schedule(
          interval,
          fetch: fetch,
          onData: onData,
          onTerminalError: onTerminalError,
        );
      }
    });
  }
}

/// Delay before the next poll after [failures] consecutive failures:
/// [interval] doubled per failure, capped at 30 s.
Duration backoff(Duration interval, int failures) {
  var delay = interval;
  for (var i = 0; i < failures && delay < _Poller.maxBackoff; i++) {
    delay *= 2;
  }
  return delay > _Poller.maxBackoff ? _Poller.maxBackoff : delay;
}

/// 401/403/404 end a poll; everything else is retried.
bool isTerminalPollError(Object error) =>
    error is UnauthorizedException ||
    error is ForbiddenException ||
    error is NotFoundException;
