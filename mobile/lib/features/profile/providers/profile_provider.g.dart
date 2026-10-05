// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$userProfileHash() => r'e1e82df0b1dfd4d5bd091bffdd6831c6b9718f24';

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

/// Another user's profile (404 when blocked either way).
///
/// Copied from [userProfile].
@ProviderFor(userProfile)
const userProfileProvider = UserProfileFamily();

/// Another user's profile (404 when blocked either way).
///
/// Copied from [userProfile].
class UserProfileFamily extends Family<AsyncValue<User>> {
  /// Another user's profile (404 when blocked either way).
  ///
  /// Copied from [userProfile].
  const UserProfileFamily();

  /// Another user's profile (404 when blocked either way).
  ///
  /// Copied from [userProfile].
  UserProfileProvider call(
    String userId,
  ) {
    return UserProfileProvider(
      userId,
    );
  }

  @override
  UserProfileProvider getProviderOverride(
    covariant UserProfileProvider provider,
  ) {
    return call(
      provider.userId,
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
  String? get name => r'userProfileProvider';
}

/// Another user's profile (404 when blocked either way).
///
/// Copied from [userProfile].
class UserProfileProvider extends AutoDisposeFutureProvider<User> {
  /// Another user's profile (404 when blocked either way).
  ///
  /// Copied from [userProfile].
  UserProfileProvider(
    String userId,
  ) : this._internal(
          (ref) => userProfile(
            ref as UserProfileRef,
            userId,
          ),
          from: userProfileProvider,
          name: r'userProfileProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$userProfileHash,
          dependencies: UserProfileFamily._dependencies,
          allTransitiveDependencies:
              UserProfileFamily._allTransitiveDependencies,
          userId: userId,
        );

  UserProfileProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.userId,
  }) : super.internal();

  final String userId;

  @override
  Override overrideWith(
    FutureOr<User> Function(UserProfileRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: UserProfileProvider._internal(
        (ref) => create(ref as UserProfileRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        userId: userId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<User> createElement() {
    return _UserProfileProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UserProfileProvider && other.userId == userId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, userId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin UserProfileRef on AutoDisposeFutureProviderRef<User> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _UserProfileProviderElement extends AutoDisposeFutureProviderElement<User>
    with UserProfileRef {
  _UserProfileProviderElement(super.provider);

  @override
  String get userId => (origin as UserProfileProvider).userId;
}

String _$userStatsHash() => r'dbf25ec73c8840077ee017385f1c80ce1acb4c42';

/// See also [userStats].
@ProviderFor(userStats)
const userStatsProvider = UserStatsFamily();

/// See also [userStats].
class UserStatsFamily extends Family<AsyncValue<UserStats>> {
  /// See also [userStats].
  const UserStatsFamily();

  /// See also [userStats].
  UserStatsProvider call(
    String userId,
  ) {
    return UserStatsProvider(
      userId,
    );
  }

  @override
  UserStatsProvider getProviderOverride(
    covariant UserStatsProvider provider,
  ) {
    return call(
      provider.userId,
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
  String? get name => r'userStatsProvider';
}

/// See also [userStats].
class UserStatsProvider extends AutoDisposeFutureProvider<UserStats> {
  /// See also [userStats].
  UserStatsProvider(
    String userId,
  ) : this._internal(
          (ref) => userStats(
            ref as UserStatsRef,
            userId,
          ),
          from: userStatsProvider,
          name: r'userStatsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$userStatsHash,
          dependencies: UserStatsFamily._dependencies,
          allTransitiveDependencies: UserStatsFamily._allTransitiveDependencies,
          userId: userId,
        );

  UserStatsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.userId,
  }) : super.internal();

  final String userId;

  @override
  Override overrideWith(
    FutureOr<UserStats> Function(UserStatsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: UserStatsProvider._internal(
        (ref) => create(ref as UserStatsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        userId: userId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<UserStats> createElement() {
    return _UserStatsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UserStatsProvider && other.userId == userId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, userId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin UserStatsRef on AutoDisposeFutureProviderRef<UserStats> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _UserStatsProviderElement
    extends AutoDisposeFutureProviderElement<UserStats> with UserStatsRef {
  _UserStatsProviderElement(super.provider);

  @override
  String get userId => (origin as UserStatsProvider).userId;
}

String _$userCollectionHash() => r'1a1ca16465780e0518e670ca3652746477992de9';

/// A user's owned games (profile Collection tab).
///
/// Copied from [userCollection].
@ProviderFor(userCollection)
const userCollectionProvider = UserCollectionFamily();

/// A user's owned games (profile Collection tab).
///
/// Copied from [userCollection].
class UserCollectionFamily extends Family<AsyncValue<List<UserGame>>> {
  /// A user's owned games (profile Collection tab).
  ///
  /// Copied from [userCollection].
  const UserCollectionFamily();

  /// A user's owned games (profile Collection tab).
  ///
  /// Copied from [userCollection].
  UserCollectionProvider call(
    String userId,
  ) {
    return UserCollectionProvider(
      userId,
    );
  }

  @override
  UserCollectionProvider getProviderOverride(
    covariant UserCollectionProvider provider,
  ) {
    return call(
      provider.userId,
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
  String? get name => r'userCollectionProvider';
}

/// A user's owned games (profile Collection tab).
///
/// Copied from [userCollection].
class UserCollectionProvider extends AutoDisposeFutureProvider<List<UserGame>> {
  /// A user's owned games (profile Collection tab).
  ///
  /// Copied from [userCollection].
  UserCollectionProvider(
    String userId,
  ) : this._internal(
          (ref) => userCollection(
            ref as UserCollectionRef,
            userId,
          ),
          from: userCollectionProvider,
          name: r'userCollectionProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$userCollectionHash,
          dependencies: UserCollectionFamily._dependencies,
          allTransitiveDependencies:
              UserCollectionFamily._allTransitiveDependencies,
          userId: userId,
        );

  UserCollectionProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.userId,
  }) : super.internal();

  final String userId;

  @override
  Override overrideWith(
    FutureOr<List<UserGame>> Function(UserCollectionRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: UserCollectionProvider._internal(
        (ref) => create(ref as UserCollectionRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        userId: userId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<UserGame>> createElement() {
    return _UserCollectionProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UserCollectionProvider && other.userId == userId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, userId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin UserCollectionRef on AutoDisposeFutureProviderRef<List<UserGame>> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _UserCollectionProviderElement
    extends AutoDisposeFutureProviderElement<List<UserGame>>
    with UserCollectionRef {
  _UserCollectionProviderElement(super.provider);

  @override
  String get userId => (origin as UserCollectionProvider).userId;
}

String _$userFavoritesHash() => r'e2b17be32f8a341b937074e08e5179ad801089f4';

/// A user's favourites (profile "Favorite Games" row).
///
/// Copied from [userFavorites].
@ProviderFor(userFavorites)
const userFavoritesProvider = UserFavoritesFamily();

/// A user's favourites (profile "Favorite Games" row).
///
/// Copied from [userFavorites].
class UserFavoritesFamily extends Family<AsyncValue<List<UserGame>>> {
  /// A user's favourites (profile "Favorite Games" row).
  ///
  /// Copied from [userFavorites].
  const UserFavoritesFamily();

  /// A user's favourites (profile "Favorite Games" row).
  ///
  /// Copied from [userFavorites].
  UserFavoritesProvider call(
    String userId,
  ) {
    return UserFavoritesProvider(
      userId,
    );
  }

  @override
  UserFavoritesProvider getProviderOverride(
    covariant UserFavoritesProvider provider,
  ) {
    return call(
      provider.userId,
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
  String? get name => r'userFavoritesProvider';
}

/// A user's favourites (profile "Favorite Games" row).
///
/// Copied from [userFavorites].
class UserFavoritesProvider extends AutoDisposeFutureProvider<List<UserGame>> {
  /// A user's favourites (profile "Favorite Games" row).
  ///
  /// Copied from [userFavorites].
  UserFavoritesProvider(
    String userId,
  ) : this._internal(
          (ref) => userFavorites(
            ref as UserFavoritesRef,
            userId,
          ),
          from: userFavoritesProvider,
          name: r'userFavoritesProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$userFavoritesHash,
          dependencies: UserFavoritesFamily._dependencies,
          allTransitiveDependencies:
              UserFavoritesFamily._allTransitiveDependencies,
          userId: userId,
        );

  UserFavoritesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.userId,
  }) : super.internal();

  final String userId;

  @override
  Override overrideWith(
    FutureOr<List<UserGame>> Function(UserFavoritesRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: UserFavoritesProvider._internal(
        (ref) => create(ref as UserFavoritesRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        userId: userId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<UserGame>> createElement() {
    return _UserFavoritesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UserFavoritesProvider && other.userId == userId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, userId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin UserFavoritesRef on AutoDisposeFutureProviderRef<List<UserGame>> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _UserFavoritesProviderElement
    extends AutoDisposeFutureProviderElement<List<UserGame>>
    with UserFavoritesRef {
  _UserFavoritesProviderElement(super.provider);

  @override
  String get userId => (origin as UserFavoritesProvider).userId;
}

String _$profileActionsHash() => r'5fde80611d1b436054a19fcd6d5614cf7563f01e';

/// Editing the signed-in user's profile.
///
/// Copied from [profileActions].
@ProviderFor(profileActions)
final profileActionsProvider = AutoDisposeProvider<ProfileActions>.internal(
  profileActions,
  name: r'profileActionsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$profileActionsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ProfileActionsRef = AutoDisposeProviderRef<ProfileActions>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
