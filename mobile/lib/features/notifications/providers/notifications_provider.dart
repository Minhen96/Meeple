import 'dart:async';

import 'package:meeple_hearth/core/network/connectivity_service.dart';
import 'package:meeple_hearth/core/push/push_providers.dart';
import 'package:meeple_hearth/core/storage/cache_store.dart';
import 'package:meeple_hearth/features/auth/domain/user_model.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/notifications/data/notification_repository.dart';
import 'package:meeple_hearth/features/notifications/data/realtime_service.dart';
import 'package:meeple_hearth/features/notifications/domain/notification_model.dart';
import 'package:meeple_hearth/shared/models/cursor_page.dart';
import 'package:meeple_hearth/shared/models/paged_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notifications_provider.g.dart';

/// Notification centre list: cursor pages, first page cached for 30 min,
/// realtime frames prepended live.
@riverpod
class NotificationsNotifier extends _$NotificationsNotifier {
  @override
  Future<PagedState<AppNotification>> build() {
    final sub = ref.read(realtimeServiceProvider).notifications.listen((n) {
      final current = state.valueOrNull;
      if (current == null) return;
      state = AsyncValue.data(
        current.copyWith(
          items: [
            n.notification,
            ...current.items.where((i) => i.id != n.notification.id),
          ],
        ),
      );
    });
    ref.onDispose(sub.cancel);
    return _firstPage();
  }

  NotificationRepository get _repo => ref.read(notificationRepositoryProvider);

  Future<PagedState<AppNotification>> _firstPage() async {
    final result = await readThrough<CursorPage<AppNotification>>(
      cache: ref.read(cacheStoreProvider),
      key: CacheKeys.notifications,
      maxAge: CacheTtl.notifications,
      fetch: _repo.getNotifications,
      encode: (page) => page.toJson((n) => n.toJson()),
      decode: (json) => CursorPage.fromJson(json, AppNotification.fromJson),
    );
    return PagedState.fromPage(result.data, cachedAt: result.cachedAt);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_firstPage);
    unawaited(ref.read(unreadCountProvider.notifier).refresh());
  }

  Future<void> loadMore() => loadNextPage<AppNotification>(
        current: state.valueOrNull,
        read: () => state.valueOrNull,
        emit: (s) => state = AsyncValue.data(s),
        fetch: (cursor) => _repo.getNotifications(cursor: cursor),
      );

  Future<void> markRead(AppNotification n) async {
    if (n.read) return;
    ensureOnline(ref);
    _update(n.id, (x) => x.copyWith(read: true));
    ref.read(unreadCountProvider.notifier).decrement();
    try {
      await _repo.markRead(n.id);
    } catch (_) {
      _update(n.id, (x) => x.copyWith(read: false));
      ref.read(unreadCountProvider.notifier).increment();
      rethrow;
    }
  }

  Future<void> markAllRead() async {
    ensureOnline(ref);
    await _repo.markAllRead();
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(
        current.mapItems((n) => !n.read, (n) => n.copyWith(read: true)),
      );
    }
    ref.read(unreadCountProvider.notifier).set(0);
  }

  Future<void> delete(AppNotification n) async {
    ensureOnline(ref);
    final before = state.valueOrNull;
    if (before != null) {
      state = AsyncValue.data(before.removeWhere((x) => x.id == n.id));
    }
    try {
      await _repo.delete(n.id);
      if (!n.read) ref.read(unreadCountProvider.notifier).decrement();
    } catch (_) {
      if (before != null) state = AsyncValue.data(before);
      rethrow;
    }
  }

  void _update(String id, AppNotification Function(AppNotification) f) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(current.mapItems((n) => n.id == id, f));
  }
}

/// Unread badge count: fetched on sign-in and refresh, then kept current by
/// realtime frames (`unreadCount`) and foreground pushes.
@Riverpod(keepAlive: true)
class UnreadCount extends _$UnreadCount {
  @override
  int build() {
    final realtime = ref.read(realtimeServiceProvider);
    final subs = [
      realtime.notifications.listen((n) {
        final count = n.unreadCount;
        count != null ? set(count) : increment();
      }),
      ref.read(pushServiceProvider).foregroundMessages.listen((_) {
        // Realtime frames carry the exact count; only refresh when the
        // socket is down.
        if (!realtime.isConnected) unawaited(refresh());
      }),
    ];
    ref
      ..onDispose(() {
        for (final s in subs) {
          s.cancel();
        }
      })
      ..listen<AsyncValue<User?>>(
        authNotifierProvider,
        (_, next) {
          if (next.valueOrNull != null) {
            unawaited(refresh());
          } else if (!next.isLoading) {
            state = 0;
          }
        },
        fireImmediately: true,
      );
    return 0;
  }

  Future<void> refresh() async {
    try {
      state = await ref.read(notificationRepositoryProvider).getUnreadCount();
    } catch (_) {
      // Keep the last known count.
    }
  }

  void set(int count) => state = count < 0 ? 0 : count;
  void increment() => state = state + 1;
  void decrement() => set(state - 1);
}

/// Per-type in-app/push toggles.
@riverpod
class NotificationPreferences extends _$NotificationPreferences {
  @override
  Future<List<NotificationPreference>> build() =>
      ref.read(notificationRepositoryProvider).getPreferences();

  Future<void> toggle(String type, {bool? inApp, bool? push}) async {
    ensureOnline(ref);
    final before = state.valueOrNull;
    if (before == null) return;
    final next = [
      for (final p in before)
        p.type == type
            ? p.copyWith(
                inAppEnabled: inApp ?? p.inAppEnabled,
                pushEnabled: push ?? p.pushEnabled,
              )
            : p,
    ];
    state = AsyncValue.data(next);
    try {
      await ref.read(notificationRepositoryProvider).savePreferences(next);
    } catch (_) {
      state = AsyncValue.data(before);
      rethrow;
    }
  }
}

/// Quiet hours.
@riverpod
class QuietHours extends _$QuietHours {
  @override
  Future<NotificationSettings> build() =>
      ref.read(notificationRepositoryProvider).getSettings();

  Future<void> save(NotificationSettings settings) async {
    ensureOnline(ref);
    final before = state.valueOrNull;
    state = AsyncValue.data(settings);
    try {
      await ref.read(notificationRepositoryProvider).saveSettings(settings);
    } catch (_) {
      if (before != null) state = AsyncValue.data(before);
      rethrow;
    }
  }
}
