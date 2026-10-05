// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feed_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$feedNotifierHash() => r'ca4c8de79702e31865682f9bb0eedb2ccae4ddf6';

/// Home feed: cursor pages of posts and friend activity, newest first.
///
/// The first page is cached (last 50 items, 1 h — MOBILE_FLUTTER §6) and
/// shown with a stale banner while offline.
///
/// Copied from [FeedNotifier].
@ProviderFor(FeedNotifier)
final feedNotifierProvider =
    AsyncNotifierProvider<FeedNotifier, PagedState<FeedItem>>.internal(
  FeedNotifier.new,
  name: r'feedNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$feedNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$FeedNotifier = AsyncNotifier<PagedState<FeedItem>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
