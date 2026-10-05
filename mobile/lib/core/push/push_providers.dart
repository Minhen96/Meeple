import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:meeple_hearth/core/config/firebase_bootstrap.dart';
import 'package:meeple_hearth/core/locale/locale_provider.dart';
import 'package:meeple_hearth/core/push/push_messaging.dart';
import 'package:meeple_hearth/core/push/push_service.dart';
import 'package:meeple_hearth/core/storage/secure_storage.dart';
import 'package:meeple_hearth/features/auth/domain/user_model.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/notifications/data/notification_repository.dart';
import 'package:meeple_hearth/l10n/gen/app_localizations.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'push_providers.g.dart';

/// Firebase Messaging, or null when Firebase is not configured.
@Riverpod(keepAlive: true)
PushMessaging? pushMessaging(Ref ref) =>
    ref.watch(firebaseReadyProvider) ? FirebasePushMessaging() : null;

/// Local notifications, only needed together with FCM.
@Riverpod(keepAlive: true)
LocalNotifications? localNotifications(Ref ref) {
  if (!ref.watch(firebaseReadyProvider)) return null;
  final l10n = lookupAppLocalizations(ref.read(appLocaleProvider).locale);
  return PluginLocalNotifications(
    eventsChannelName: l10n.pushChannelEvents,
    eventsChannelDescription: l10n.pushChannelEventsDescription,
    socialChannelName: l10n.pushChannelSocial,
    socialChannelDescription: l10n.pushChannelSocialDescription,
  );
}

/// The push service, started/stopped with the auth state. Logout
/// unregisters the device token while the session is still valid.
@Riverpod(keepAlive: true)
PushService pushService(Ref ref) {
  final service = PushService(
    messaging: ref.watch(pushMessagingProvider),
    local: ref.watch(localNotificationsProvider),
    repository: ref.read(notificationRepositoryProvider),
    storage: ref.read(secureStorageProvider),
  );
  final removeHook = ref.read(logoutHooksProvider).add(service.stop);
  ref
    ..listen<AsyncValue<User?>>(
      authNotifierProvider,
      (_, next) {
        if (next.isLoading) return;
        if (next.valueOrNull != null) {
          unawaited(service.start());
        } else {
          unawaited(service.stop());
        }
      },
      fireImmediately: true,
    )
    ..onDispose(() {
      removeHook();
      unawaited(service.dispose());
    });
  return service;
}
