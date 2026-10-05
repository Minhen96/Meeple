// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$accountActionsHash() => r'2e0de718f79fef90af840435d703fad92169c8f6';

/// See also [accountActions].
@ProviderFor(accountActions)
final accountActionsProvider = AutoDisposeProvider<AccountActions>.internal(
  accountActions,
  name: r'accountActionsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$accountActionsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AccountActionsRef = AutoDisposeProviderRef<AccountActions>;
String _$activeSessionsHash() => r'd0ee040a1bfa53229aa2a8708acb1816067bdd1c';

/// Active sessions (refresh tokens) of the account.
///
/// Copied from [ActiveSessions].
@ProviderFor(ActiveSessions)
final activeSessionsProvider = AutoDisposeAsyncNotifierProvider<ActiveSessions,
    List<ActiveSession>>.internal(
  ActiveSessions.new,
  name: r'activeSessionsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$activeSessionsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ActiveSessions = AutoDisposeAsyncNotifier<List<ActiveSession>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
