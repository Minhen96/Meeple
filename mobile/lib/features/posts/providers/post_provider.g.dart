// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$postChangesHash() => r'32b0a08b7d4f1df681e07b2cd2ef9d2deec10693';

/// See also [postChanges].
@ProviderFor(postChanges)
final postChangesProvider =
    Provider<Raw<StreamController<PostChange>>>.internal(
  postChanges,
  name: r'postChangesProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$postChangesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PostChangesRef = ProviderRef<Raw<StreamController<PostChange>>>;
String _$postActionsHash() => r'319524cfd18125920c99a0aa21a5d076a68642de';

/// Likes, bookmarks, edits and deletes with optimistic updates
/// (MOBILE_FLUTTER §4) and the offline write guard (§11).
///
/// Copied from [postActions].
@ProviderFor(postActions)
final postActionsProvider = AutoDisposeProvider<PostActions>.internal(
  postActions,
  name: r'postActionsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$postActionsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PostActionsRef = AutoDisposeProviderRef<PostActions>;
String _$eventPostsHash() => r'18ef7e83a596393bb8c1a1b0e7df461cba935e42';

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

/// Posts tagged to an event ("View Memories").
///
/// Copied from [eventPosts].
@ProviderFor(eventPosts)
const eventPostsProvider = EventPostsFamily();

/// Posts tagged to an event ("View Memories").
///
/// Copied from [eventPosts].
class EventPostsFamily extends Family<AsyncValue<List<Post>>> {
  /// Posts tagged to an event ("View Memories").
  ///
  /// Copied from [eventPosts].
  const EventPostsFamily();

  /// Posts tagged to an event ("View Memories").
  ///
  /// Copied from [eventPosts].
  EventPostsProvider call(
    String eventId,
  ) {
    return EventPostsProvider(
      eventId,
    );
  }

  @override
  EventPostsProvider getProviderOverride(
    covariant EventPostsProvider provider,
  ) {
    return call(
      provider.eventId,
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
  String? get name => r'eventPostsProvider';
}

/// Posts tagged to an event ("View Memories").
///
/// Copied from [eventPosts].
class EventPostsProvider extends AutoDisposeFutureProvider<List<Post>> {
  /// Posts tagged to an event ("View Memories").
  ///
  /// Copied from [eventPosts].
  EventPostsProvider(
    String eventId,
  ) : this._internal(
          (ref) => eventPosts(
            ref as EventPostsRef,
            eventId,
          ),
          from: eventPostsProvider,
          name: r'eventPostsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$eventPostsHash,
          dependencies: EventPostsFamily._dependencies,
          allTransitiveDependencies:
              EventPostsFamily._allTransitiveDependencies,
          eventId: eventId,
        );

  EventPostsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.eventId,
  }) : super.internal();

  final String eventId;

  @override
  Override overrideWith(
    FutureOr<List<Post>> Function(EventPostsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: EventPostsProvider._internal(
        (ref) => create(ref as EventPostsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        eventId: eventId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Post>> createElement() {
    return _EventPostsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is EventPostsProvider && other.eventId == eventId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, eventId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin EventPostsRef on AutoDisposeFutureProviderRef<List<Post>> {
  /// The parameter `eventId` of this provider.
  String get eventId;
}

class _EventPostsProviderElement
    extends AutoDisposeFutureProviderElement<List<Post>> with EventPostsRef {
  _EventPostsProviderElement(super.provider);

  @override
  String get eventId => (origin as EventPostsProvider).eventId;
}

String _$postDetailHash() => r'efa7fecaae9826607392a10ed551f8c3a9730c28';

abstract class _$PostDetail extends BuildlessAutoDisposeAsyncNotifier<Post> {
  late final String postId;

  FutureOr<Post> build(
    String postId,
  );
}

/// A single post; follows [postChanges].
///
/// Copied from [PostDetail].
@ProviderFor(PostDetail)
const postDetailProvider = PostDetailFamily();

/// A single post; follows [postChanges].
///
/// Copied from [PostDetail].
class PostDetailFamily extends Family<AsyncValue<Post>> {
  /// A single post; follows [postChanges].
  ///
  /// Copied from [PostDetail].
  const PostDetailFamily();

  /// A single post; follows [postChanges].
  ///
  /// Copied from [PostDetail].
  PostDetailProvider call(
    String postId,
  ) {
    return PostDetailProvider(
      postId,
    );
  }

  @override
  PostDetailProvider getProviderOverride(
    covariant PostDetailProvider provider,
  ) {
    return call(
      provider.postId,
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
  String? get name => r'postDetailProvider';
}

/// A single post; follows [postChanges].
///
/// Copied from [PostDetail].
class PostDetailProvider
    extends AutoDisposeAsyncNotifierProviderImpl<PostDetail, Post> {
  /// A single post; follows [postChanges].
  ///
  /// Copied from [PostDetail].
  PostDetailProvider(
    String postId,
  ) : this._internal(
          () => PostDetail()..postId = postId,
          from: postDetailProvider,
          name: r'postDetailProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$postDetailHash,
          dependencies: PostDetailFamily._dependencies,
          allTransitiveDependencies:
              PostDetailFamily._allTransitiveDependencies,
          postId: postId,
        );

  PostDetailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.postId,
  }) : super.internal();

  final String postId;

  @override
  FutureOr<Post> runNotifierBuild(
    covariant PostDetail notifier,
  ) {
    return notifier.build(
      postId,
    );
  }

  @override
  Override overrideWith(PostDetail Function() create) {
    return ProviderOverride(
      origin: this,
      override: PostDetailProvider._internal(
        () => create()..postId = postId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        postId: postId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<PostDetail, Post> createElement() {
    return _PostDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PostDetailProvider && other.postId == postId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, postId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PostDetailRef on AutoDisposeAsyncNotifierProviderRef<Post> {
  /// The parameter `postId` of this provider.
  String get postId;
}

class _PostDetailProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<PostDetail, Post>
    with PostDetailRef {
  _PostDetailProviderElement(super.provider);

  @override
  String get postId => (origin as PostDetailProvider).postId;
}

String _$commentsNotifierHash() => r'd0e0689f864535390c5ec39798c2bdcafc90ff11';

abstract class _$CommentsNotifier
    extends BuildlessAutoDisposeAsyncNotifier<PagedState<Comment>> {
  late final String postId;

  FutureOr<PagedState<Comment>> build(
    String postId,
  );
}

/// Comments of a post (paged).
///
/// Copied from [CommentsNotifier].
@ProviderFor(CommentsNotifier)
const commentsNotifierProvider = CommentsNotifierFamily();

/// Comments of a post (paged).
///
/// Copied from [CommentsNotifier].
class CommentsNotifierFamily extends Family<AsyncValue<PagedState<Comment>>> {
  /// Comments of a post (paged).
  ///
  /// Copied from [CommentsNotifier].
  const CommentsNotifierFamily();

  /// Comments of a post (paged).
  ///
  /// Copied from [CommentsNotifier].
  CommentsNotifierProvider call(
    String postId,
  ) {
    return CommentsNotifierProvider(
      postId,
    );
  }

  @override
  CommentsNotifierProvider getProviderOverride(
    covariant CommentsNotifierProvider provider,
  ) {
    return call(
      provider.postId,
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
  String? get name => r'commentsNotifierProvider';
}

/// Comments of a post (paged).
///
/// Copied from [CommentsNotifier].
class CommentsNotifierProvider extends AutoDisposeAsyncNotifierProviderImpl<
    CommentsNotifier, PagedState<Comment>> {
  /// Comments of a post (paged).
  ///
  /// Copied from [CommentsNotifier].
  CommentsNotifierProvider(
    String postId,
  ) : this._internal(
          () => CommentsNotifier()..postId = postId,
          from: commentsNotifierProvider,
          name: r'commentsNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$commentsNotifierHash,
          dependencies: CommentsNotifierFamily._dependencies,
          allTransitiveDependencies:
              CommentsNotifierFamily._allTransitiveDependencies,
          postId: postId,
        );

  CommentsNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.postId,
  }) : super.internal();

  final String postId;

  @override
  FutureOr<PagedState<Comment>> runNotifierBuild(
    covariant CommentsNotifier notifier,
  ) {
    return notifier.build(
      postId,
    );
  }

  @override
  Override overrideWith(CommentsNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: CommentsNotifierProvider._internal(
        () => create()..postId = postId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        postId: postId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<CommentsNotifier, PagedState<Comment>>
      createElement() {
    return _CommentsNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CommentsNotifierProvider && other.postId == postId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, postId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CommentsNotifierRef
    on AutoDisposeAsyncNotifierProviderRef<PagedState<Comment>> {
  /// The parameter `postId` of this provider.
  String get postId;
}

class _CommentsNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<CommentsNotifier,
        PagedState<Comment>> with CommentsNotifierRef {
  _CommentsNotifierProviderElement(super.provider);

  @override
  String get postId => (origin as CommentsNotifierProvider).postId;
}

String _$userPostsHash() => r'2bdaa6b51d6302d73c06436dc0d09040b5f91a9b';

abstract class _$UserPosts
    extends BuildlessAutoDisposeAsyncNotifier<PagedState<Post>> {
  late final String userId;

  FutureOr<PagedState<Post>> build(
    String userId,
  );
}

/// Paged posts of a user (profile Posts tab).
///
/// Copied from [UserPosts].
@ProviderFor(UserPosts)
const userPostsProvider = UserPostsFamily();

/// Paged posts of a user (profile Posts tab).
///
/// Copied from [UserPosts].
class UserPostsFamily extends Family<AsyncValue<PagedState<Post>>> {
  /// Paged posts of a user (profile Posts tab).
  ///
  /// Copied from [UserPosts].
  const UserPostsFamily();

  /// Paged posts of a user (profile Posts tab).
  ///
  /// Copied from [UserPosts].
  UserPostsProvider call(
    String userId,
  ) {
    return UserPostsProvider(
      userId,
    );
  }

  @override
  UserPostsProvider getProviderOverride(
    covariant UserPostsProvider provider,
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
  String? get name => r'userPostsProvider';
}

/// Paged posts of a user (profile Posts tab).
///
/// Copied from [UserPosts].
class UserPostsProvider
    extends AutoDisposeAsyncNotifierProviderImpl<UserPosts, PagedState<Post>> {
  /// Paged posts of a user (profile Posts tab).
  ///
  /// Copied from [UserPosts].
  UserPostsProvider(
    String userId,
  ) : this._internal(
          () => UserPosts()..userId = userId,
          from: userPostsProvider,
          name: r'userPostsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$userPostsHash,
          dependencies: UserPostsFamily._dependencies,
          allTransitiveDependencies: UserPostsFamily._allTransitiveDependencies,
          userId: userId,
        );

  UserPostsProvider._internal(
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
  FutureOr<PagedState<Post>> runNotifierBuild(
    covariant UserPosts notifier,
  ) {
    return notifier.build(
      userId,
    );
  }

  @override
  Override overrideWith(UserPosts Function() create) {
    return ProviderOverride(
      origin: this,
      override: UserPostsProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<UserPosts, PagedState<Post>>
      createElement() {
    return _UserPostsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UserPostsProvider && other.userId == userId;
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
mixin UserPostsRef on AutoDisposeAsyncNotifierProviderRef<PagedState<Post>> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _UserPostsProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<UserPosts, PagedState<Post>>
    with UserPostsRef {
  _UserPostsProviderElement(super.provider);

  @override
  String get userId => (origin as UserPostsProvider).userId;
}

String _$bookmarksHash() => r'cace511a5b087210c76387d7cc356f95d8b52f0d';

/// The viewer's saved posts.
///
/// Copied from [Bookmarks].
@ProviderFor(Bookmarks)
final bookmarksProvider =
    AutoDisposeAsyncNotifierProvider<Bookmarks, PagedState<Post>>.internal(
  Bookmarks.new,
  name: r'bookmarksProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$bookmarksHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$Bookmarks = AutoDisposeAsyncNotifier<PagedState<Post>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
