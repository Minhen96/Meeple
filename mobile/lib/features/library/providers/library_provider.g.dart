// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$gameDetailHash() => r'add0c9573ae21021df973cc9b44d6e27023855d1';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Game detail, cached for 7 days.
///
/// Copied from [gameDetail].
@ProviderFor(gameDetail)
const gameDetailProvider = GameDetailFamily();

/// Game detail, cached for 7 days.
///
/// Copied from [gameDetail].
class GameDetailFamily extends Family<AsyncValue<CachedResult<Game>>> {
  /// Game detail, cached for 7 days.
  ///
  /// Copied from [gameDetail].
  const GameDetailFamily();

  /// Game detail, cached for 7 days.
  ///
  /// Copied from [gameDetail].
  GameDetailProvider call(
    String gameId,
  ) {
    return GameDetailProvider(
      gameId,
    );
  }

  @override
  GameDetailProvider getProviderOverride(
    covariant GameDetailProvider provider,
  ) {
    return call(
      provider.gameId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'gameDetailProvider';
}

/// Game detail, cached for 7 days.
///
/// Copied from [gameDetail].
class GameDetailProvider extends AutoDisposeFutureProvider<CachedResult<Game>> {
  /// Game detail, cached for 7 days.
  ///
  /// Copied from [gameDetail].
  GameDetailProvider(
    String gameId,
  ) : this._internal(
          (ref) => gameDetail(
            ref as GameDetailRef,
            gameId,
          ),
          from: gameDetailProvider,
          name: r'gameDetailProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$gameDetailHash,
          dependencies: GameDetailFamily._dependencies,
          allTransitiveDependencies:
              GameDetailFamily._allTransitiveDependencies,
          gameId: gameId,
        );

  GameDetailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.gameId,
  }) : super.internal();

  final String gameId;

  @override
  Override overrideWith(
    FutureOr<CachedResult<Game>> Function(GameDetailRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GameDetailProvider._internal(
        (ref) => create(ref as GameDetailRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        gameId: gameId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<CachedResult<Game>> createElement() {
    return _GameDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GameDetailProvider && other.gameId == gameId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, gameId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GameDetailRef on AutoDisposeFutureProviderRef<CachedResult<Game>> {
  /// The parameter `gameId` of this provider.
  String get gameId;
}

class _GameDetailProviderElement
    extends AutoDisposeFutureProviderElement<CachedResult<Game>>
    with GameDetailRef {
  _GameDetailProviderElement(super.provider);

  @override
  String get gameId => (origin as GameDetailProvider).gameId;
}

String _$gameFriendsHash() => r'74d99f091955e32f705094b886f4cdcc0e99c495';

/// See also [gameFriends].
@ProviderFor(gameFriends)
const gameFriendsProvider = GameFriendsFamily();

/// See also [gameFriends].
class GameFriendsFamily extends Family<AsyncValue<List<FriendGameEntry>>> {
  /// See also [gameFriends].
  const GameFriendsFamily();

  /// See also [gameFriends].
  GameFriendsProvider call(
    String gameId,
  ) {
    return GameFriendsProvider(
      gameId,
    );
  }

  @override
  GameFriendsProvider getProviderOverride(
    covariant GameFriendsProvider provider,
  ) {
    return call(
      provider.gameId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'gameFriendsProvider';
}

/// See also [gameFriends].
class GameFriendsProvider
    extends AutoDisposeFutureProvider<List<FriendGameEntry>> {
  /// See also [gameFriends].
  GameFriendsProvider(
    String gameId,
  ) : this._internal(
          (ref) => gameFriends(
            ref as GameFriendsRef,
            gameId,
          ),
          from: gameFriendsProvider,
          name: r'gameFriendsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$gameFriendsHash,
          dependencies: GameFriendsFamily._dependencies,
          allTransitiveDependencies:
              GameFriendsFamily._allTransitiveDependencies,
          gameId: gameId,
        );

  GameFriendsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.gameId,
  }) : super.internal();

  final String gameId;

  @override
  Override overrideWith(
    FutureOr<List<FriendGameEntry>> Function(GameFriendsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GameFriendsProvider._internal(
        (ref) => create(ref as GameFriendsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        gameId: gameId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<FriendGameEntry>> createElement() {
    return _GameFriendsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GameFriendsProvider && other.gameId == gameId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, gameId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GameFriendsRef on AutoDisposeFutureProviderRef<List<FriendGameEntry>> {
  /// The parameter `gameId` of this provider.
  String get gameId;
}

class _GameFriendsProviderElement
    extends AutoDisposeFutureProviderElement<List<FriendGameEntry>>
    with GameFriendsRef {
  _GameFriendsProviderElement(super.provider);

  @override
  String get gameId => (origin as GameFriendsProvider).gameId;
}

String _$gameReviewsHash() => r'db37cc1c927cb1508f271a1ab514627481be20a6';

/// See also [gameReviews].
@ProviderFor(gameReviews)
const gameReviewsProvider = GameReviewsFamily();

/// See also [gameReviews].
class GameReviewsFamily extends Family<AsyncValue<List<GameReview>>> {
  /// See also [gameReviews].
  const GameReviewsFamily();

  /// See also [gameReviews].
  GameReviewsProvider call(
    String gameId,
  ) {
    return GameReviewsProvider(
      gameId,
    );
  }

  @override
  GameReviewsProvider getProviderOverride(
    covariant GameReviewsProvider provider,
  ) {
    return call(
      provider.gameId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'gameReviewsProvider';
}

/// See also [gameReviews].
class GameReviewsProvider extends AutoDisposeFutureProvider<List<GameReview>> {
  /// See also [gameReviews].
  GameReviewsProvider(
    String gameId,
  ) : this._internal(
          (ref) => gameReviews(
            ref as GameReviewsRef,
            gameId,
          ),
          from: gameReviewsProvider,
          name: r'gameReviewsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$gameReviewsHash,
          dependencies: GameReviewsFamily._dependencies,
          allTransitiveDependencies:
              GameReviewsFamily._allTransitiveDependencies,
          gameId: gameId,
        );

  GameReviewsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.gameId,
  }) : super.internal();

  final String gameId;

  @override
  Override overrideWith(
    FutureOr<List<GameReview>> Function(GameReviewsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GameReviewsProvider._internal(
        (ref) => create(ref as GameReviewsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        gameId: gameId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<GameReview>> createElement() {
    return _GameReviewsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GameReviewsProvider && other.gameId == gameId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, gameId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GameReviewsRef on AutoDisposeFutureProviderRef<List<GameReview>> {
  /// The parameter `gameId` of this provider.
  String get gameId;
}

class _GameReviewsProviderElement
    extends AutoDisposeFutureProviderElement<List<GameReview>>
    with GameReviewsRef {
  _GameReviewsProviderElement(super.provider);

  @override
  String get gameId => (origin as GameReviewsProvider).gameId;
}

String _$gamePlaysHash() => r'3a7bb355b1ce2658d4d17913b430a5d06efdc14c';

/// See also [gamePlays].
@ProviderFor(gamePlays)
const gamePlaysProvider = GamePlaysFamily();

/// See also [gamePlays].
class GamePlaysFamily extends Family<AsyncValue<List<PlayLog>>> {
  /// See also [gamePlays].
  const GamePlaysFamily();

  /// See also [gamePlays].
  GamePlaysProvider call(
    String gameId,
  ) {
    return GamePlaysProvider(
      gameId,
    );
  }

  @override
  GamePlaysProvider getProviderOverride(
    covariant GamePlaysProvider provider,
  ) {
    return call(
      provider.gameId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'gamePlaysProvider';
}

/// See also [gamePlays].
class GamePlaysProvider extends AutoDisposeFutureProvider<List<PlayLog>> {
  /// See also [gamePlays].
  GamePlaysProvider(
    String gameId,
  ) : this._internal(
          (ref) => gamePlays(
            ref as GamePlaysRef,
            gameId,
          ),
          from: gamePlaysProvider,
          name: r'gamePlaysProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$gamePlaysHash,
          dependencies: GamePlaysFamily._dependencies,
          allTransitiveDependencies: GamePlaysFamily._allTransitiveDependencies,
          gameId: gameId,
        );

  GamePlaysProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.gameId,
  }) : super.internal();

  final String gameId;

  @override
  Override overrideWith(
    FutureOr<List<PlayLog>> Function(GamePlaysRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GamePlaysProvider._internal(
        (ref) => create(ref as GamePlaysRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        gameId: gameId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<PlayLog>> createElement() {
    return _GamePlaysProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GamePlaysProvider && other.gameId == gameId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, gameId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GamePlaysRef on AutoDisposeFutureProviderRef<List<PlayLog>> {
  /// The parameter `gameId` of this provider.
  String get gameId;
}

class _GamePlaysProviderElement
    extends AutoDisposeFutureProviderElement<List<PlayLog>> with GamePlaysRef {
  _GamePlaysProviderElement(super.provider);

  @override
  String get gameId => (origin as GamePlaysProvider).gameId;
}

String _$collectionNotifierHash() =>
    r'6c6472d7a5711bd59426cff8dab76ba4146f6639';

/// `GET /users/me/games?filter=all`, cached for 24 h (MOBILE_FLUTTER §6).
/// Tabs are derived client-side from the multi-boolean flags.
///
/// Copied from [CollectionNotifier].
@ProviderFor(CollectionNotifier)
final collectionNotifierProvider =
    AsyncNotifierProvider<CollectionNotifier, CollectionState>.internal(
  CollectionNotifier.new,
  name: r'collectionNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$collectionNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CollectionNotifier = AsyncNotifier<CollectionState>;
String _$gameSearchNotifierHash() =>
    r'de63d106445c10f79349a946724aaeba6ddd6280';

abstract class _$GameSearchNotifier
    extends BuildlessAutoDisposeAsyncNotifier<PaginatedResult<Game>> {
  late final String query;

  FutureOr<PaginatedResult<Game>> build(
    String query,
  );
}

/// Browse / search the game catalogue (page-based Spring page).
///
/// Copied from [GameSearchNotifier].
@ProviderFor(GameSearchNotifier)
const gameSearchNotifierProvider = GameSearchNotifierFamily();

/// Browse / search the game catalogue (page-based Spring page).
///
/// Copied from [GameSearchNotifier].
class GameSearchNotifierFamily
    extends Family<AsyncValue<PaginatedResult<Game>>> {
  /// Browse / search the game catalogue (page-based Spring page).
  ///
  /// Copied from [GameSearchNotifier].
  const GameSearchNotifierFamily();

  /// Browse / search the game catalogue (page-based Spring page).
  ///
  /// Copied from [GameSearchNotifier].
  GameSearchNotifierProvider call(
    String query,
  ) {
    return GameSearchNotifierProvider(
      query,
    );
  }

  @override
  GameSearchNotifierProvider getProviderOverride(
    covariant GameSearchNotifierProvider provider,
  ) {
    return call(
      provider.query,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'gameSearchNotifierProvider';
}

/// Browse / search the game catalogue (page-based Spring page).
///
/// Copied from [GameSearchNotifier].
class GameSearchNotifierProvider extends AutoDisposeAsyncNotifierProviderImpl<
    GameSearchNotifier, PaginatedResult<Game>> {
  /// Browse / search the game catalogue (page-based Spring page).
  ///
  /// Copied from [GameSearchNotifier].
  GameSearchNotifierProvider(
    String query,
  ) : this._internal(
          () => GameSearchNotifier()..query = query,
          from: gameSearchNotifierProvider,
          name: r'gameSearchNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$gameSearchNotifierHash,
          dependencies: GameSearchNotifierFamily._dependencies,
          allTransitiveDependencies:
              GameSearchNotifierFamily._allTransitiveDependencies,
          query: query,
        );

  GameSearchNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.query,
  }) : super.internal();

  final String query;

  @override
  FutureOr<PaginatedResult<Game>> runNotifierBuild(
    covariant GameSearchNotifier notifier,
  ) {
    return notifier.build(
      query,
    );
  }

  @override
  Override overrideWith(GameSearchNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: GameSearchNotifierProvider._internal(
        () => create()..query = query,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        query: query,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<GameSearchNotifier,
      PaginatedResult<Game>> createElement() {
    return _GameSearchNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GameSearchNotifierProvider && other.query == query;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, query.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GameSearchNotifierRef
    on AutoDisposeAsyncNotifierProviderRef<PaginatedResult<Game>> {
  /// The parameter `query` of this provider.
  String get query;
}

class _GameSearchNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<GameSearchNotifier,
        PaginatedResult<Game>> with GameSearchNotifierRef {
  _GameSearchNotifierProviderElement(super.provider);

  @override
  String get query => (origin as GameSearchNotifierProvider).query;
}

String _$gameSessionsHash() => r'a571059ee7d76b7eb58e14ed31f11a66b18e68bc';

abstract class _$GameSessions
    extends BuildlessAutoDisposeAsyncNotifier<PagedState<Post>> {
  late final String gameId;

  FutureOr<PagedState<Post>> build(
    String gameId,
  );
}

/// Posts tagged with a game (Sessions tab).
///
/// Copied from [GameSessions].
@ProviderFor(GameSessions)
const gameSessionsProvider = GameSessionsFamily();

/// Posts tagged with a game (Sessions tab).
///
/// Copied from [GameSessions].
class GameSessionsFamily extends Family<AsyncValue<PagedState<Post>>> {
  /// Posts tagged with a game (Sessions tab).
  ///
  /// Copied from [GameSessions].
  const GameSessionsFamily();

  /// Posts tagged with a game (Sessions tab).
  ///
  /// Copied from [GameSessions].
  GameSessionsProvider call(
    String gameId,
  ) {
    return GameSessionsProvider(
      gameId,
    );
  }

  @override
  GameSessionsProvider getProviderOverride(
    covariant GameSessionsProvider provider,
  ) {
    return call(
      provider.gameId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'gameSessionsProvider';
}

/// Posts tagged with a game (Sessions tab).
///
/// Copied from [GameSessions].
class GameSessionsProvider extends AutoDisposeAsyncNotifierProviderImpl<
    GameSessions, PagedState<Post>> {
  /// Posts tagged with a game (Sessions tab).
  ///
  /// Copied from [GameSessions].
  GameSessionsProvider(
    String gameId,
  ) : this._internal(
          () => GameSessions()..gameId = gameId,
          from: gameSessionsProvider,
          name: r'gameSessionsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$gameSessionsHash,
          dependencies: GameSessionsFamily._dependencies,
          allTransitiveDependencies:
              GameSessionsFamily._allTransitiveDependencies,
          gameId: gameId,
        );

  GameSessionsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.gameId,
  }) : super.internal();

  final String gameId;

  @override
  FutureOr<PagedState<Post>> runNotifierBuild(
    covariant GameSessions notifier,
  ) {
    return notifier.build(
      gameId,
    );
  }

  @override
  Override overrideWith(GameSessions Function() create) {
    return ProviderOverride(
      origin: this,
      override: GameSessionsProvider._internal(
        () => create()..gameId = gameId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        gameId: gameId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<GameSessions, PagedState<Post>>
      createElement() {
    return _GameSessionsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GameSessionsProvider && other.gameId == gameId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, gameId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GameSessionsRef on AutoDisposeAsyncNotifierProviderRef<PagedState<Post>> {
  /// The parameter `gameId` of this provider.
  String get gameId;
}

class _GameSessionsProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<GameSessions,
        PagedState<Post>> with GameSessionsRef {
  _GameSessionsProviderElement(super.provider);

  @override
  String get gameId => (origin as GameSessionsProvider).gameId;
}

String _$howToPlayNotifierHash() => r'b66ba13bf425a710a970cd9be6d0d3cd709c9646';

abstract class _$HowToPlayNotifier
    extends BuildlessAutoDisposeAsyncNotifier<HowToPlay> {
  late final String gameId;

  FutureOr<HowToPlay> build(
    String gameId,
  );
}

/// How-to-Play guide; polls every 3 s while it is being generated.
///
/// Transient poll failures keep the last guide and retry with backoff; only a
/// 401/403/404 ends polling with an error.
///
/// Copied from [HowToPlayNotifier].
@ProviderFor(HowToPlayNotifier)
const howToPlayNotifierProvider = HowToPlayNotifierFamily();

/// How-to-Play guide; polls every 3 s while it is being generated.
///
/// Transient poll failures keep the last guide and retry with backoff; only a
/// 401/403/404 ends polling with an error.
///
/// Copied from [HowToPlayNotifier].
class HowToPlayNotifierFamily extends Family<AsyncValue<HowToPlay>> {
  /// How-to-Play guide; polls every 3 s while it is being generated.
  ///
  /// Transient poll failures keep the last guide and retry with backoff; only a
  /// 401/403/404 ends polling with an error.
  ///
  /// Copied from [HowToPlayNotifier].
  const HowToPlayNotifierFamily();

  /// How-to-Play guide; polls every 3 s while it is being generated.
  ///
  /// Transient poll failures keep the last guide and retry with backoff; only a
  /// 401/403/404 ends polling with an error.
  ///
  /// Copied from [HowToPlayNotifier].
  HowToPlayNotifierProvider call(
    String gameId,
  ) {
    return HowToPlayNotifierProvider(
      gameId,
    );
  }

  @override
  HowToPlayNotifierProvider getProviderOverride(
    covariant HowToPlayNotifierProvider provider,
  ) {
    return call(
      provider.gameId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'howToPlayNotifierProvider';
}

/// How-to-Play guide; polls every 3 s while it is being generated.
///
/// Transient poll failures keep the last guide and retry with backoff; only a
/// 401/403/404 ends polling with an error.
///
/// Copied from [HowToPlayNotifier].
class HowToPlayNotifierProvider
    extends AutoDisposeAsyncNotifierProviderImpl<HowToPlayNotifier, HowToPlay> {
  /// How-to-Play guide; polls every 3 s while it is being generated.
  ///
  /// Transient poll failures keep the last guide and retry with backoff; only a
  /// 401/403/404 ends polling with an error.
  ///
  /// Copied from [HowToPlayNotifier].
  HowToPlayNotifierProvider(
    String gameId,
  ) : this._internal(
          () => HowToPlayNotifier()..gameId = gameId,
          from: howToPlayNotifierProvider,
          name: r'howToPlayNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$howToPlayNotifierHash,
          dependencies: HowToPlayNotifierFamily._dependencies,
          allTransitiveDependencies:
              HowToPlayNotifierFamily._allTransitiveDependencies,
          gameId: gameId,
        );

  HowToPlayNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.gameId,
  }) : super.internal();

  final String gameId;

  @override
  FutureOr<HowToPlay> runNotifierBuild(
    covariant HowToPlayNotifier notifier,
  ) {
    return notifier.build(
      gameId,
    );
  }

  @override
  Override overrideWith(HowToPlayNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: HowToPlayNotifierProvider._internal(
        () => create()..gameId = gameId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        gameId: gameId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<HowToPlayNotifier, HowToPlay>
      createElement() {
    return _HowToPlayNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is HowToPlayNotifierProvider && other.gameId == gameId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, gameId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin HowToPlayNotifierRef on AutoDisposeAsyncNotifierProviderRef<HowToPlay> {
  /// The parameter `gameId` of this provider.
  String get gameId;
}

class _HowToPlayNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<HowToPlayNotifier,
        HowToPlay> with HowToPlayNotifierRef {
  _HowToPlayNotifierProviderElement(super.provider);

  @override
  String get gameId => (origin as HowToPlayNotifierProvider).gameId;
}

String _$bggImportHash() => r'0894bb7bf547b6fca235c8f247bee9c4665607c3';

/// BGG collection import with 2 s progress polling (SCREENS §3.4).
///
/// Polling stops on a terminal status (`done`/`failed`/`idle`) or a
/// 401/403/404; transient failures keep the last status and retry with
/// backoff.
///
/// Copied from [BggImport].
@ProviderFor(BggImport)
final bggImportProvider =
    AutoDisposeAsyncNotifierProvider<BggImport, BggImportStatus>.internal(
  BggImport.new,
  name: r'bggImportProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$bggImportHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$BggImport = AutoDisposeAsyncNotifier<BggImportStatus>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
