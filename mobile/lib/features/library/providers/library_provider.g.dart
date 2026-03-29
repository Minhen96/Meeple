// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$gameDetailHash() => r'867ecf84019506596ab419514d3705dcd1bb29ac';

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

/// Single game detail.
///
/// Copied from [gameDetail].
@ProviderFor(gameDetail)
const gameDetailProvider = GameDetailFamily();

/// Single game detail.
///
/// Copied from [gameDetail].
class GameDetailFamily extends Family<AsyncValue<Game>> {
  /// Single game detail.
  ///
  /// Copied from [gameDetail].
  const GameDetailFamily();

  /// Single game detail.
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

/// Single game detail.
///
/// Copied from [gameDetail].
class GameDetailProvider extends AutoDisposeFutureProvider<Game> {
  /// Single game detail.
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
    FutureOr<Game> Function(GameDetailRef provider) create,
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
  AutoDisposeFutureProviderElement<Game> createElement() {
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
mixin GameDetailRef on AutoDisposeFutureProviderRef<Game> {
  /// The parameter `gameId` of this provider.
  String get gameId;
}

class _GameDetailProviderElement extends AutoDisposeFutureProviderElement<Game>
    with GameDetailRef {
  _GameDetailProviderElement(super.provider);

  @override
  String get gameId => (origin as GameDetailProvider).gameId;
}

String _$collectionNotifierHash() =>
    r'89bc6c71570e6f240f1deef13ac158d2aad0839b';

/// My collection — full list (no pagination; API returns all owned/wishlisted).
///
/// Copied from [CollectionNotifier].
@ProviderFor(CollectionNotifier)
final collectionNotifierProvider = AutoDisposeAsyncNotifierProvider<
    CollectionNotifier, List<UserGame>>.internal(
  CollectionNotifier.new,
  name: r'collectionNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$collectionNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CollectionNotifier = AutoDisposeAsyncNotifier<List<UserGame>>;
String _$gameSearchNotifierHash() =>
    r'a9cba404b5c3dbef57f6ed3915b60d3bcdb72dff';

abstract class _$GameSearchNotifier
    extends BuildlessAutoDisposeAsyncNotifier<PaginatedResult<Game>> {
  late final String query;

  FutureOr<PaginatedResult<Game>> build(
    String query,
  );
}

/// Game search results.
///
/// Copied from [GameSearchNotifier].
@ProviderFor(GameSearchNotifier)
const gameSearchNotifierProvider = GameSearchNotifierFamily();

/// Game search results.
///
/// Copied from [GameSearchNotifier].
class GameSearchNotifierFamily
    extends Family<AsyncValue<PaginatedResult<Game>>> {
  /// Game search results.
  ///
  /// Copied from [GameSearchNotifier].
  const GameSearchNotifierFamily();

  /// Game search results.
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

/// Game search results.
///
/// Copied from [GameSearchNotifier].
class GameSearchNotifierProvider extends AutoDisposeAsyncNotifierProviderImpl<
    GameSearchNotifier, PaginatedResult<Game>> {
  /// Game search results.
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
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
