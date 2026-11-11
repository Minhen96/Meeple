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
import 'package:meeple_hearth/shared/widgets/app_card.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:meeple_hearth/shared/widgets/skeleton_widget.dart';
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
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                textStyle: AppTypography.labelLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(l10n.notificationsMarkAllRead),
            ),
          BarIconButton(
            tooltip: l10n.notificationPrefsTitle,
            icon: Icons.tune_rounded,
            onPressed: () => context.push(AppRoutes.notificationPrefs),
          ),
        ],
      ),
      body: list.when(
        loading: () => const _NotificationsSkeleton(),
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
                SectionLabel(
                  switch (g) {
                    NotificationGroup.today => l10n.notificationsToday,
                    NotificationGroup.thisWeek => l10n.notificationsThisWeek,
                    NotificationGroup.earlier => l10n.notificationsEarlier,
                  },
                  padding: EdgeInsets.fromLTRB(
                    4,
                    rows.isEmpty ? 0 : AppSpacing.xl,
                    4,
                    AppSpacing.sm,
                  ),
                ),
              );
            }
            rows.add(
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _NotificationTile(
                  notification: n,
                  onTap: () => _open(n),
                  onMarkRead: () => _guard(() => notifier.markRead(n)),
                  onDelete: () => _guard(() => notifier.delete(n)),
                ),
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
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                children: [
                  if (state.cachedAt != null)
                    StaleDataBanner(cachedAt: state.cachedAt!),
                  if (state.items.isEmpty)
                    const _EmptyNotifications()
                  else ...[
                    ...rows,
                    if (state.hasMore || state.loadMoreError != null)
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

/// Web empty state: faded check icon, "You're all caught up!" and a hint.
class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = AppTypography.bodyMedium.copyWith(
      color: AppColors.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 48,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          AppSpacing.vGapMd,
          Text(
            l10n.allCaughtUp,
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          AppSpacing.vGapSm,
          Text(
            l10n.notificationsEmptyBody,
            textAlign: TextAlign.center,
            style: style,
          ),
        ],
      ),
    );
  }
}

class _NotificationsSkeleton extends StatelessWidget {
  const _NotificationsSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          0,
        ),
        children: [
          for (var i = 0; i < 5; i++)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.all(Radius.circular(AppRadius.tile)),
              ),
              child: const SkeletonShimmer(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonCircle(size: 40),
                    AppSpacing.hGapMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 96, height: 12),
                          AppSpacing.vGapSm,
                          SkeletonBox(width: 180, height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
}

/// Icon shown instead of an avatar for notifications without an actor
/// (web `typeIcon`).
IconData notificationTypeIcon(String type) {
  if (type.startsWith('EVENT_')) return Icons.event_outlined;
  if (type.startsWith('MATCH_')) return Icons.groups_outlined;
  if (type == 'POST_LIKE') return Icons.favorite_border_rounded;
  if (type == 'POST_COMMENT' || type == 'COMMENT_MENTION') {
    return Icons.chat_bubble_outline_rounded;
  }
  if (type == 'POST_TAG') return Icons.sell_outlined;
  if (type.startsWith('FRIEND_')) return Icons.person_add_alt_outlined;
  if (type == 'BGG_IMPORT_COMPLETED') return Icons.library_add_outlined;
  return Icons.menu_book_outlined;
}

/// Web notification card: rounded-xl, tinted while unread (with a primary
/// dot), avatar (or type icon), bold title over the body, time on the
/// right, and mark-read / delete buttons. Swipe right marks read, left
/// deletes.
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

  static const _radius = BorderRadius.all(Radius.circular(AppRadius.tile));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final n = notification;
    final serverTitle = n.title?.trim() ?? '';
    final serverBody = n.body?.trim() ?? '';
    final title =
        serverTitle.isNotEmpty ? serverTitle : notificationText(l10n, n);
    final body =
        serverTitle.isNotEmpty && serverBody.isNotEmpty ? serverBody : null;
    final actor = n.actor;
    final showAvatar = actor != null && !actor.deleted;
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
        borderRadius: _radius,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (!n.read)
              Positioned(
                left: 6,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    key: ValueKey('unread-${n.id}'),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InkWell(
                      key: ValueKey('notification-open-${n.id}'),
                      onTap: onTap,
                      borderRadius: AppSpacing.borderRadiusLg,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showAvatar)
                            AppAvatar(
                              imageUrl: actor.avatarUrl,
                              displayName: actor.displayName,
                            )
                          else
                            Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                notificationTypeIcon(n.type),
                                size: 20,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          AppSpacing.hGapMd,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                                if (body != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    body,
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          AppSpacing.hGapMd,
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              AppDateUtils.timeAgoCompact(n.createdAt, l10n),
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AppSpacing.hGapXs,
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!n.read)
                        _SmallAction(
                          key: ValueKey('mark-read-${n.id}'),
                          icon: Icons.done_rounded,
                          color: AppColors.tertiary,
                          tooltip: l10n.notificationsMarkRead,
                          onTap: onMarkRead,
                        ),
                      if (!n.read) AppSpacing.vGapXs,
                      _SmallAction(
                        key: ValueKey('delete-${n.id}'),
                        icon: Icons.delete_outline_rounded,
                        color: AppColors.error,
                        tooltip: l10n.notificationsDelete,
                        onTap: onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 32px round icon button (mark read / delete).
class _SmallAction extends StatelessWidget {
  const _SmallAction({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkResponse(
          onTap: onTap,
          radius: 16,
          child: SizedBox.square(
            dimension: 32,
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      );
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
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.onError),
                ),
              ],
            ),
          ),
        ),
      );
}
