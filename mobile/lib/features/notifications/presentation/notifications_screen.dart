import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/core/utils/app_date_utils.dart';
import 'package:meeple_hearth/features/notifications/domain/notification_model.dart';
import 'package:meeple_hearth/features/notifications/presentation/notification_text.dart';
import 'package:meeple_hearth/features/notifications/providers/notifications_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_avatar.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/empty_state.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:meeple_hearth/shared/widgets/status_banners.dart';

/// Today / This Week / Earlier grouping (SCREENS §9).
enum NotificationGroup { today, thisWeek, earlier }

NotificationGroup groupOf(DateTime createdAt, {DateTime? now}) {
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final day = DateUtils.dateOnly(createdAt.toLocal());
  if (!day.isBefore(today)) return NotificationGroup.today;
  if (today.difference(day).inDays < 7) return NotificationGroup.thisWeek;
  return NotificationGroup.earlier;
}

/// Notification centre: grouped list, swipe to mark read / delete, tap to
/// open `data.path`, cursor paging and live updates.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  Future<void> _guard(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _open(AppNotification n) async {
    final notifier = ref.read(notificationsNotifierProvider.notifier);
    if (!n.read) await _guard(() => notifier.markRead(n));
    final path = n.path;
    if (path != null && mounted) await context.push(path);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final list = ref.watch(notificationsNotifierProvider);
    final notifier = ref.read(notificationsNotifierProvider.notifier);
    final hasUnread = list.valueOrNull?.items.any((n) => !n.read) ?? false;
    return Scaffold(
      appBar: MeepleAppBar(
        title: l10n.notificationsTitle,
        showBackButton: true,
        actions: [
          if (hasUnread)
            TextButton(
              key: const Key('mark-all-read'),
              onPressed: () => _guard(notifier.markAllRead),
              child: Text(l10n.notificationsMarkAllRead),
            ),
          IconButton(
            tooltip: l10n.notificationPrefsTitle,
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => context.push(AppRoutes.notificationPrefs),
          ),
        ],
      ),
      body: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(notificationsNotifierProvider),
        ),
        data: (state) {
          final rows = <Widget>[];
          NotificationGroup? current;
          for (final n in state.items) {
            final g = groupOf(n.createdAt);
            if (g != current) {
              current = g;
              rows.add(
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xs,
                  ),
                  child: Text(
                    switch (g) {
                      NotificationGroup.today => l10n.notificationsToday,
                      NotificationGroup.thisWeek => l10n.notificationsThisWeek,
                      NotificationGroup.earlier => l10n.notificationsEarlier,
                    },
                    style: AppTypography.labelMedium,
                  ),
                ),
              );
            }
            rows.add(
              _NotificationTile(
                notification: n,
                onTap: () => _open(n),
                onMarkRead: () => _guard(() => notifier.markRead(n)),
                onDelete: () => _guard(() => notifier.delete(n)),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: notifier.refresh,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels >= n.metrics.maxScrollExtent * 0.8) {
                  notifier.loadMore();
                }
                return false;
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (state.cachedAt != null)
                    StaleDataBanner(cachedAt: state.cachedAt!),
                  if (state.items.isEmpty)
                    EmptyState(
                      icon: Icons.check_circle_outline_rounded,
                      title: l10n.allCaughtUp,
                      subtitle: l10n.notificationsEmptyBody,
                    )
                  else ...[
                    ...rows,
                    ListFooter(
                      isLoading: state.isLoadingMore,
                      hasMore: state.hasMore,
                      error: state.loadMoreError,
                      onRetry: notifier.loadMore,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onMarkRead,
    required this.onDelete,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onMarkRead;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final n = notification;
    return Dismissible(
      key: ValueKey('notification-${n.id}'),
      background: _SwipeBackground(
        color: AppColors.tertiary,
        icon: Icons.mark_email_read_outlined,
        label: l10n.notificationsMarkRead,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _SwipeBackground(
        color: AppColors.error,
        icon: Icons.delete_outline_rounded,
        label: l10n.commonDelete,
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onMarkRead();
          return false;
        }
        return true;
      },
      onDismissed: (_) => onDelete(),
      child: Material(
        color: n.read ? AppColors.surface : AppColors.surfaceContainerLow,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 10,
                  child: n.read
                      ? null
                      : Container(
                          key: ValueKey('unread-${n.id}'),
                          margin: const EdgeInsets.only(top: 16),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                ),
                AppSpacing.hGapXs,
                AppAvatar(
                  imageUrl: n.actor?.avatarUrl,
                  displayName: n.actor?.displayName ?? '•',
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notificationText(l10n, n),
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: n.read ? FontWeight.w400 : FontWeight.w600,
                        ),
                      ),
                      AppSpacing.vGapXs,
                      Text(
                        AppDateUtils.timeAgo(n.createdAt, l10n),
                        style: AppTypography.labelSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  final Color color;
  final IconData icon;
  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: color,
        child: Align(
          alignment: alignment,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppColors.onError),
                AppSpacing.hGapSm,
                Text(
                  label,
                  style: AppTypography.labelLarge.copyWith(color: AppColors.onError),
                ),
              ],
            ),
          ),
        ),
      );
}
