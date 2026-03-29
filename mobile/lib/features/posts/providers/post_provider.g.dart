// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$postDetailHash() => r'371726bdddc7eed1eb205ba0b7888e59dfc3b8c4';

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

/// Single post detail.
///
/// Copied from [postDetail].
@ProviderFor(postDetail)
const postDetailProvider = PostDetailFamily();

/// Single post detail.
///
/// Copied from [postDetail].
class PostDetailFamily extends Family<AsyncValue<Post>> {
  /// Single post detail.
  ///
  /// Copied from [postDetail].
  const PostDetailFamily();

  /// Single post detail.
  ///
  /// Copied from [postDetail].
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

/// Single post detail.
///
/// Copied from [postDetail].
class PostDetailProvider extends AutoDisposeFutureProvider<Post> {
  /// Single post detail.
  ///
  /// Copied from [postDetail].
  PostDetailProvider(
    String postId,
  ) : this._internal(
          (ref) => postDetail(
            ref as PostDetailRef,
            postId,
          ),
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
  Override overrideWith(
    FutureOr<Post> Function(PostDetailRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PostDetailProvider._internal(
        (ref) => create(ref as PostDetailRef),
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
  AutoDisposeFutureProviderElement<Post> createElement() {
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
mixin PostDetailRef on AutoDisposeFutureProviderRef<Post> {
  /// The parameter `postId` of this provider.
  String get postId;
}

class _PostDetailProviderElement extends AutoDisposeFutureProviderElement<Post>
    with PostDetailRef {
  _PostDetailProviderElement(super.provider);

  @override
  String get postId => (origin as PostDetailProvider).postId;
}

String _$commentsNotifierHash() => r'60d9c6e9b149c38b60c637bbf6f2d87ae0fa54df';

abstract class _$CommentsNotifier
    extends BuildlessAutoDisposeAsyncNotifier<PaginatedResult<Comment>> {
  late final String postId;

  FutureOr<PaginatedResult<Comment>> build(
    String postId,
  );
}

/// Paginated comments for a post.
///
/// Copied from [CommentsNotifier].
@ProviderFor(CommentsNotifier)
const commentsNotifierProvider = CommentsNotifierFamily();

/// Paginated comments for a post.
///
/// Copied from [CommentsNotifier].
class CommentsNotifierFamily
    extends Family<AsyncValue<PaginatedResult<Comment>>> {
  /// Paginated comments for a post.
  ///
  /// Copied from [CommentsNotifier].
  const CommentsNotifierFamily();

  /// Paginated comments for a post.
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

/// Paginated comments for a post.
///
/// Copied from [CommentsNotifier].
class CommentsNotifierProvider extends AutoDisposeAsyncNotifierProviderImpl<
    CommentsNotifier, PaginatedResult<Comment>> {
  /// Paginated comments for a post.
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
  FutureOr<PaginatedResult<Comment>> runNotifierBuild(
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
  AutoDisposeAsyncNotifierProviderElement<CommentsNotifier,
      PaginatedResult<Comment>> createElement() {
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
    on AutoDisposeAsyncNotifierProviderRef<PaginatedResult<Comment>> {
  /// The parameter `postId` of this provider.
  String get postId;
}

class _CommentsNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<CommentsNotifier,
        PaginatedResult<Comment>> with CommentsNotifierRef {
  _CommentsNotifierProviderElement(super.provider);

  @override
  String get postId => (origin as CommentsNotifierProvider).postId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
