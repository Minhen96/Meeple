// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'matching_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$matchSuggestionsHash() => r'6574bf535cbb5562e87626e24c9887d9e8a61f61';

/// Pending match suggestions (home card + matching screen).
///
/// Copied from [MatchSuggestions].
@ProviderFor(MatchSuggestions)
final matchSuggestionsProvider = AutoDisposeAsyncNotifierProvider<
    MatchSuggestions, List<MatchGroup>>.internal(
  MatchSuggestions.new,
  name: r'matchSuggestionsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$matchSuggestionsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MatchSuggestions = AutoDisposeAsyncNotifier<List<MatchGroup>>;
String _$myMatchRequestsHash() => r'39716dbc66177a269e4667f564fc3e1b9870f2c3';

/// The viewer's active match requests.
///
/// Copied from [MyMatchRequests].
@ProviderFor(MyMatchRequests)
final myMatchRequestsProvider = AutoDisposeAsyncNotifierProvider<
    MyMatchRequests, List<MatchRequest>>.internal(
  MyMatchRequests.new,
  name: r'myMatchRequestsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$myMatchRequestsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MyMatchRequests = AutoDisposeAsyncNotifier<List<MatchRequest>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
