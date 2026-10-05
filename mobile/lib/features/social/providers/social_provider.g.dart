// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'social_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$blockedUsersHash() => r'a32368de500e69d454b601497496ae1771af2378';

/// See also [blockedUsers].
@ProviderFor(blockedUsers)
final blockedUsersProvider =
    AutoDisposeFutureProvider<List<UserSummary>>.internal(
  blockedUsers,
  name: r'blockedUsersProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$blockedUsersHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BlockedUsersRef = AutoDisposeFutureProviderRef<List<UserSummary>>;
String _$userSearchHash() => r'20a6741b409c6a149b1f4d87f81746309a5c770b';

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

/// See also [userSearch].
@ProviderFor(userSearch)
const userSearchProvider = UserSearchFamily();

/// See also [userSearch].
class UserSearchFamily extends Family<AsyncValue<List<UserSummary>>> {
  /// See also [userSearch].
  const UserSearchFamily();

  /// See also [userSearch].
  UserSearchProvider call(
    String query,
  ) {
    return UserSearchProvider(
      query,
    );
  }

  @override
  UserSearchProvider getProviderOverride(
    covariant UserSearchProvider provider,
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
  String? get name => r'userSearchProvider';
}

/// See also [userSearch].
class UserSearchProvider extends AutoDisposeFutureProvider<List<UserSummary>> {
  /// See also [userSearch].
  UserSearchProvider(
    String query,
  ) : this._internal(
          (ref) => userSearch(
            ref as UserSearchRef,
            query,
          ),
          from: userSearchProvider,
          name: r'userSearchProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$userSearchHash,
          dependencies: UserSearchFamily._dependencies,
          allTransitiveDependencies:
              UserSearchFamily._allTransitiveDependencies,
          query: query,
        );

  UserSearchProvider._internal(
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
  Override overrideWith(
    FutureOr<List<UserSummary>> Function(UserSearchRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: UserSearchProvider._internal(
        (ref) => create(ref as UserSearchRef),
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
  AutoDisposeFutureProviderElement<List<UserSummary>> createElement() {
    return _UserSearchProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UserSearchProvider && other.query == query;
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
mixin UserSearchRef on AutoDisposeFutureProviderRef<List<UserSummary>> {
  /// The parameter `query` of this provider.
  String get query;
}

class _UserSearchProviderElement
    extends AutoDisposeFutureProviderElement<List<UserSummary>>
    with UserSearchRef {
  _UserSearchProviderElement(super.provider);

  @override
  String get query => (origin as UserSearchProvider).query;
}

String _$reportActionsHash() => r'176a01ce6de4f0f6ca5a604586857eeb66c692e3';

/// Reporting users, posts and comments (`POST /reports`).
///
/// Copied from [reportActions].
@ProviderFor(reportActions)
final reportActionsProvider = AutoDisposeProvider<ReportActions>.internal(
  reportActions,
  name: r'reportActionsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$reportActionsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ReportActionsRef = AutoDisposeProviderRef<ReportActions>;
String _$friendStatusNotifierHash() =>
    r'ae65df555aab0e3b036a85337747022a3f0d1a1d';

abstract class _$FriendStatusNotifier
    extends BuildlessAutoDisposeAsyncNotifier<FriendStatus> {
  late final String userId;

  FutureOr<FriendStatus> build(
    String userId,
  );
}

/// Friendship with one user and the "Add Friend → Pending → Friends" actions
/// (CLAUDE.md social rules).
///
/// Copied from [FriendStatusNotifier].
@ProviderFor(FriendStatusNotifier)
const friendStatusNotifierProvider = FriendStatusNotifierFamily();

/// Friendship with one user and the "Add Friend → Pending → Friends" actions
/// (CLAUDE.md social rules).
///
/// Copied from [FriendStatusNotifier].
class FriendStatusNotifierFamily extends Family<AsyncValue<FriendStatus>> {
  /// Friendship with one user and the "Add Friend → Pending → Friends" actions
  /// (CLAUDE.md social rules).
  ///
  /// Copied from [FriendStatusNotifier].
  const FriendStatusNotifierFamily();

  /// Friendship with one user and the "Add Friend → Pending → Friends" actions
  /// (CLAUDE.md social rules).
  ///
  /// Copied from [FriendStatusNotifier].
  FriendStatusNotifierProvider call(
    String userId,
  ) {
    return FriendStatusNotifierProvider(
      userId,
    );
  }

  @override
  FriendStatusNotifierProvider getProviderOverride(
    covariant FriendStatusNotifierProvider provider,
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
  String? get name => r'friendStatusNotifierProvider';
}

/// Friendship with one user and the "Add Friend → Pending → Friends" actions
/// (CLAUDE.md social rules).
///
/// Copied from [FriendStatusNotifier].
class FriendStatusNotifierProvider extends AutoDisposeAsyncNotifierProviderImpl<
    FriendStatusNotifier, FriendStatus> {
  /// Friendship with one user and the "Add Friend → Pending → Friends" actions
  /// (CLAUDE.md social rules).
  ///
  /// Copied from [FriendStatusNotifier].
  FriendStatusNotifierProvider(
    String userId,
  ) : this._internal(
          () => FriendStatusNotifier()..userId = userId,
          from: friendStatusNotifierProvider,
          name: r'friendStatusNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$friendStatusNotifierHash,
          dependencies: FriendStatusNotifierFamily._dependencies,
          allTransitiveDependencies:
              FriendStatusNotifierFamily._allTransitiveDependencies,
          userId: userId,
        );

  FriendStatusNotifierProvider._internal(
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
  FutureOr<FriendStatus> runNotifierBuild(
    covariant FriendStatusNotifier notifier,
  ) {
    return notifier.build(
      userId,
    );
  }

  @override
  Override overrideWith(FriendStatusNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: FriendStatusNotifierProvider._internal(
        () => create()..userId = userId,
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
  AutoDisposeAsyncNotifierProviderElement<FriendStatusNotifier, FriendStatus>
      createElement() {
    return _FriendStatusNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is FriendStatusNotifierProvider && other.userId == userId;
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
mixin FriendStatusNotifierRef
    on AutoDisposeAsyncNotifierProviderRef<FriendStatus> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _FriendStatusNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<FriendStatusNotifier,
        FriendStatus> with FriendStatusNotifierRef {
  _FriendStatusNotifierProviderElement(super.provider);

  @override
  String get userId => (origin as FriendStatusNotifierProvider).userId;
}

String _$friendsListHash() => r'31edb1eba9a50ea3f998abb94407135c850495be';

/// See also [FriendsList].
@ProviderFor(FriendsList)
final friendsListProvider = AutoDisposeAsyncNotifierProvider<FriendsList,
    PagedState<UserSummary>>.internal(
  FriendsList.new,
  name: r'friendsListProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$friendsListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$FriendsList = AutoDisposeAsyncNotifier<PagedState<UserSummary>>;
String _$receivedRequestsHash() => r'a064fccb14e0a19906c012e76baf495894862c11';

/// Requests other users sent to the viewer.
///
/// Copied from [ReceivedRequests].
@ProviderFor(ReceivedRequests)
final receivedRequestsProvider = AutoDisposeAsyncNotifierProvider<
    ReceivedRequests, List<FriendRequest>>.internal(
  ReceivedRequests.new,
  name: r'receivedRequestsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$receivedRequestsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ReceivedRequests = AutoDisposeAsyncNotifier<List<FriendRequest>>;
String _$sentRequestsHash() => r'23fb1347a142abb29f7d1d28805f2e159d108853';

/// Requests the viewer sent (still pending).
///
/// Copied from [SentRequests].
@ProviderFor(SentRequests)
final sentRequestsProvider = AutoDisposeAsyncNotifierProvider<SentRequests,
    List<FriendRequest>>.internal(
  SentRequests.new,
  name: r'sentRequestsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$sentRequestsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SentRequests = AutoDisposeAsyncNotifier<List<FriendRequest>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
