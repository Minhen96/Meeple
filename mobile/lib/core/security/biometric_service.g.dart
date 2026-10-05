// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'biometric_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$deviceAuthenticatorHash() =>
    r'5523e76d07f9188f22429481e3ef6da89d6a4330';

/// See also [deviceAuthenticator].
@ProviderFor(deviceAuthenticator)
final deviceAuthenticatorProvider = Provider<DeviceAuthenticator>.internal(
  deviceAuthenticator,
  name: r'deviceAuthenticatorProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$deviceAuthenticatorHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DeviceAuthenticatorRef = ProviderRef<DeviceAuthenticator>;
String _$biometricLockHash() => r'2f446e2d36c32e626e2db821d1150784d5134254';

/// Whether the biometric app lock is switched on (stored on the device).
///
/// Copied from [BiometricLock].
@ProviderFor(BiometricLock)
final biometricLockProvider =
    AsyncNotifierProvider<BiometricLock, bool>.internal(
  BiometricLock.new,
  name: r'biometricLockProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$biometricLockHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$BiometricLock = AsyncNotifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
