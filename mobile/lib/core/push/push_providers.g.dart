// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$pushMessagingHash() => r'1e3d45ff79497e6aacdae9de42fe375a52efabcd';

/// Firebase Messaging, or null when Firebase is not configured.
///
/// Copied from [pushMessaging].
@ProviderFor(pushMessaging)
final pushMessagingProvider = Provider<PushMessaging?>.internal(
  pushMessaging,
  name: r'pushMessagingProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$pushMessagingHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PushMessagingRef = ProviderRef<PushMessaging?>;
String _$localNotificationsHash() =>
    r'a2faa212495e9303385535def94b440de49c71af';

/// Local notifications, only needed together with FCM.
///
/// Copied from [localNotifications].
@ProviderFor(localNotifications)
final localNotificationsProvider = Provider<LocalNotifications?>.internal(
  localNotifications,
  name: r'localNotificationsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$localNotificationsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LocalNotificationsRef = ProviderRef<LocalNotifications?>;
String _$pushServiceHash() => r'43a5ab7a2bf0ab27d4585e62ee7bfe9ea33010dc';

/// The push service, started/stopped with the auth state. Logout
/// unregisters the device token while the session is still valid.
///
/// Copied from [pushService].
@ProviderFor(pushService)
final pushServiceProvider = Provider<PushService>.internal(
  pushService,
  name: r'pushServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$pushServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PushServiceRef = ProviderRef<PushService>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
