import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/notifications/providers/notifications_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';

/// Bell with the unread badge (hidden when 0) → notifications. Part of
/// [MeepleBrandBar]; the badge matches the web (error fill, 10px bold,
/// 16px tall, "99+" cap).
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadCountProvider);
    return IconButton(
      key: const Key('notification-bell'),
      tooltip: context.l10n.notificationsTitle,
      onPressed: () => context.push(AppRoutes.notifications),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      color: AppColors.onSurfaceVariant,
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        largeSize: 16,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        offset: const Offset(4, -4),
        textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        backgroundColor: AppColors.error,
        textColor: AppColors.onError,
        child: const Icon(Icons.notifications_outlined, size: 24),
      ),
    );
  }
}
