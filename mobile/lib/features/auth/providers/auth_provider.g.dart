// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$logoutHooksHash() => r'adbc86b976b7356c1239ec3fe1fdb36cb089b65b';

/// See also [logoutHooks].
@ProviderFor(logoutHooks)
final logoutHooksProvider = Provider<LogoutHooks>.internal(
  logoutHooks,
  name: r'logoutHooksProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$logoutHooksHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LogoutHooksRef = ProviderRef<LogoutHooks>;
String _$authUserIdHash() => r'93ef6e64916a59cf8911651df2a96ff13b51c4a8';

/// The signed-in user's id, or null when signed out (or still restoring).
///
/// Long-lived (`keepAlive`) providers holding user-scoped data watch this so
/// they rebuild — dropping the previous account's data — whenever the
/// account changes (logout, session expiry, sign-in as someone else). Profile
/// edits keep the id and therefore do not rebuild them.
///
/// Copied from [authUserId].
@ProviderFor(authUserId)
final authUserIdProvider = Provider<String?>.internal(
  authUserId,
  name: r'authUserIdProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$authUserIdHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuthUserIdRef = ProviderRef<String?>;
String _$authNotifierHash() => r'0f875e06c4cd12f94c3a58b83ce14b2ee1c6b880';

/// See also [AuthNotifier].
@ProviderFor(AuthNotifier)
final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, User?>.internal(
  AuthNotifier.new,
  name: r'authNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$authNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AuthNotifier = AsyncNotifier<User?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
