import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/core/utils/app_date_utils.dart';
import 'package:meeple_hearth/features/home/domain/feed_item_model.dart';
import 'package:meeple_hearth/features/matching/domain/match_model.dart';
import 'package:meeple_hearth/features/matching/providers/matching_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_avatar.dart';
import 'package:meeple_hearth/shared/widgets/app_card.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/user_widgets.dart';

/// "[Avatar] Name added *Game* to their collection." (SCREENS §7.3).
class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.item});

  final FeedActivityItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final a = item.activity;
    final name = displayNameOf(context, a.user);
    // The target (game / event) is rendered in italic primary: build the
    // sentence with a marker and split around it.
    const marker = '\u2063';
    final (String sentence, String? target, VoidCallback? onTap) =
        switch (a.type) {
      'collection_add' => (
          l10n.activityCollectionAdd(name, marker),
          a.gameName ?? l10n.notificationAGame,
          a.gameId == null
              ? null
              : () => context.push(AppRoutes.gameDetail(a.gameId!)),
        ),
      'event_created' => (
          l10n.activityEventCreated(name, marker),
          a.eventTitle ?? l10n.notificationAnEvent,
          a.eventId == null
              ? null
              : () => context.push(AppRoutes.eventDetail(a.eventId!)),
        ),
      'event_joined' => (
          l10n.activityEventJoined(name, marker),
          a.eventTitle ?? l10n.notificationAnEvent,
          a.eventId == null
              ? null
              : () => context.push(AppRoutes.eventDetail(a.eventId!)),
        ),
      _ => (l10n.activityGeneric(name), null, null),
    };
    final parts = sentence.split(marker);
    final source = a.type == 'collection_add'
        ? l10n.activityFromLibrary
        : l10n.activityFromEvents;
    final thumb = a.gameThumbnailUrl;
    // Web ActivityItem: rounded-2xl surface-container-low row.
    return AppCard(
      onTap: onTap,
      radius: AppRadius.card,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(
            imageUrl: a.user.deleted ? null : a.user.avatarUrl,
            displayName: name,
            onTap: a.user.deleted
                ? null
                : () => context.push(AppRoutes.userProfile(a.user.id)),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    style: AppTypography.bodyMedium.copyWith(height: 1.375),
                    children: [
                      TextSpan(text: parts.first),
                      if (target != null && parts.length > 1) ...[
                        TextSpan(
                          text: target,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(text: parts.sublist(1).join()),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${AppDateUtils.timeAgo(item.createdAt, l10n)} · $source',
                  style: AppTypography.labelSmall,
                ),
              ],
            ),
          ),
          if (thumb != null && thumb.isNotEmpty) ...[
            AppSpacing.hGapMd,
            ClipOval(
              child: SizedBox(
                width: 40,
                height: 40,
                child: CachedNetworkImage(
                  imageUrl: thumb,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const ColoredBox(
                    color: AppColors.surfaceContainerHigh,
                    child: Icon(
                      Icons.casino_outlined,
                      size: 20,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Match suggestion card (DESIGN match card; SCREENS §4.4).
class MatchSuggestionCard extends ConsumerStatefulWidget {
  const MatchSuggestionCard({super.key, required this.group, this.width});

  final MatchGroup group;
  final double? width;

  @override
  ConsumerState<MatchSuggestionCard> createState() =>
      _MatchSuggestionCardState();
}

class _MatchSuggestionCardState extends ConsumerState<MatchSuggestionCard> {
  bool _busy = false;

  Future<void> _dismiss() async {
    setState(() => _busy = true);
    try {
      await ref.read(matchSuggestionsProvider.notifier).dismiss(widget.group.id);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final g = widget.group;
    final window = g.overlapStart == null
        ? null
        : g.overlapEnd == null
            ? AppDateUtils.formatDateTime(g.overlapStart!)
            : '${AppDateUtils.formatDateTime(g.overlapStart!)} – '
                '${AppDateUtils.formatTime(g.overlapEnd!)}';
    return Container(
      width: widget.width,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.12),
        borderRadius: AppSpacing.borderRadiusXl,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: AppSpacing.borderRadiusLg,
            child: SizedBox(
              width: 64,
              height: 64,
              child: g.game.coverUrl == null
                  ? const ColoredBox(
                      color: AppColors.surfaceContainerHigh,
                      child: Icon(Icons.casino_outlined),
                    )
                  : CachedNetworkImage(
                      imageUrl: g.game.coverUrl!,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.matchFriendsWantToPlay(g.members.length, g.game.name),
                  style: AppTypography.titleSmall,
                ),
                if (window != null) ...[
                  AppSpacing.vGapXs,
                  Text(window, style: AppTypography.bodySmall),
                ],
                AppSpacing.vGapSm,
                AvatarStack(users: g.members),
                AppSpacing.vGapSm,
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    FilledButton(
                      key: ValueKey('match-create-${g.id}'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: const StadiumBorder(),
                      ),
                      onPressed: _busy
                          ? null
                          : () => context
                              .push(AppRoutes.createEventFromMatch(g.id)),
                      child: Text(l10n.createEvent),
                    ),
                    TextButton(
                      key: ValueKey('match-dismiss-${g.id}'),
                      onPressed: _busy ? null : _dismiss,
                      child: Text(l10n.matchDismiss),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
