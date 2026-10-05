// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notifications_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$notificationsNotifierHash() =>
    r'2df122c37ff1d4cfc6f020968ea0690225c23254';

/// Notification centre list: cursor pages, first page cached for 30 min,
/// realtime frames prepended live.
///
/// Copied from [NotificationsNotifier].
@ProviderFor(NotificationsNotifier)
final notificationsNotifierProvider = AutoDisposeAsyncNotifierProvider<
    NotificationsNotifier, PagedState<AppNotification>>.internal(
  NotificationsNotifier.new,
  name: r'notificationsNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$notificationsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$NotificationsNotifier
    = AutoDisposeAsyncNotifier<PagedState<AppNotification>>;
String _$unreadCountHash() => r'7ad1d2b02f95f4942247403ade220eeb07b834ab';

/// Unread badge count: fetched on sign-in and refresh, then kept current by
/// realtime frames (`unreadCount`) and foreground pushes.
///
/// Copied from [UnreadCount].
@ProviderFor(UnreadCount)
final unreadCountProvider = NotifierProvider<UnreadCount, int>.internal(
  UnreadCount.new,
  name: r'unreadCountProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$unreadCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$UnreadCount = Notifier<int>;
String _$notificationPreferencesHash() =>
    r'331f6ccf7c5c96ae4bdf4ca63fda12b96665795e';

/// Per-type in-app/push toggles.
///
/// Copied from [NotificationPreferences].
@ProviderFor(NotificationPreferences)
final notificationPreferencesProvider = AutoDisposeAsyncNotifierProvider<
    NotificationPreferences, List<NotificationPreference>>.internal(
  NotificationPreferences.new,
  name: r'notificationPreferencesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$notificationPreferencesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$NotificationPreferences
    = AutoDisposeAsyncNotifier<List<NotificationPreference>>;
String _$quietHoursHash() => r'a81990cd4f66e9002679695f8a9c36c5011deaa2';

/// Quiet hours.
///
/// Copied from [QuietHours].
@ProviderFor(QuietHours)
final quietHoursProvider =
    AutoDisposeAsyncNotifierProvider<QuietHours, NotificationSettings>.internal(
  QuietHours.new,
  name: r'quietHoursProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$quietHoursHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$QuietHours = AutoDisposeAsyncNotifier<NotificationSettings>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
