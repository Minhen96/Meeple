import 'package:meeple_hearth/features/library/data/collection_repository.dart';
import 'package:meeple_hearth/features/library/data/game_repository.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/features/library/domain/user_game_model.dart';
import 'package:meeple_hearth/shared/models/pagination_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'library_provider.g.dart';

/// My collection — full list (`GET /users/me/games` is not paginated).
@riverpod
class CollectionNotifier extends _$CollectionNotifier {
  @override
  Future<List<UserGame>> build() =>
      ref.read(collectionRepositoryProvider).getMyCollection();

  Future<void> refresh() async {
    state = const AsyncValue<List<UserGame>>.loading();
    state = await AsyncValue.guard<List<UserGame>>(
      () => ref.read(collectionRepositoryProvider).getMyCollection(),
    );
  }

  /// Adds a game to the collection (PUT upsert keyed by game id).
  Future<void> addGame({
    required String gameId,
    bool isOwned = false,
    bool isFavorited = false,
  }) async {
    final added = await ref.read(collectionRepositoryProvider).upsertUserGame(
          gameId: gameId,
          isOwned: isOwned,
          isFavorited: isFavorited,
        );
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([
      ...current.where((g) => g.gameId != gameId),
      added,
    ]);
  }

  Future<void> updateGame({
    required String gameId,
    bool? isOwned,
    bool? isFavorited,
    double? personalRating,
    String? notes,
  }) async {
    final updated = await ref.read(collectionRepositoryProvider).upsertUserGame(
          gameId: gameId,
          isOwned: isOwned,
          isFavorited: isFavorited,
          personalRating: personalRating,
          notes: notes,
        );
    _replace(updated);
  }

  Future<void> logPlay(String gameId) async {
    final updated =
        await ref.read(collectionRepositoryProvider).logPlay(gameId);
    _replace(updated);
  }

  Future<void> removeGame(String gameId) async {
    await ref.read(collectionRepositoryProvider).removeFromCollection(gameId);
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(current.where((g) => g.gameId != gameId).toList());
  }

  void _replace(UserGame updated) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current
          .map((UserGame g) => g.gameId == updated.gameId ? updated : g)
          .toList(),
    );
  }
}

/// Game search results.
@riverpod
class GameSearchNotifier extends _$GameSearchNotifier {
  static const _pageSize = 20;

  @override
  Future<PaginatedResult<Game>> build(String query) =>
      ref.read(gameRepositoryProvider).searchGames(
            query: query,
            params: PageParams(size: _pageSize),
          );

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;

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
  }
}

/// Single game detail.
@riverpod
Future<Game> gameDetail(GameDetailRef ref, String gameId) =>
    ref.read(gameRepositoryProvider).getGame(gameId);
