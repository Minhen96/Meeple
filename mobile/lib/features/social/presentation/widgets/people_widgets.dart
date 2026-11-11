import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/constants/text_style_weight.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/shared/models/user_summary.dart';
import 'package:meeple_hearth/shared/widgets/app_avatar.dart';
import 'package:meeple_hearth/shared/widgets/user_widgets.dart';

/// Card shapes of the web people lists.
enum PersonCardStyle {
  /// Friends list: `rounded-3xl p-4 gap-4 shadow-sm`.
  friend,

  /// People / requests rows: `rounded-xl p-3 gap-3`.
  row,
}

/// A person on a surface-container-low card — avatar (48px), name, subtitle
/// (@handle by default) and a trailing action. Tapping opens the profile.
class PersonCard extends StatelessWidget {
  const PersonCard({
    super.key,
    required this.user,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.style = PersonCardStyle.row,
  });

  final UserSummary user;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final PersonCardStyle style;

  @override
  Widget build(BuildContext context) {
    final name = displayNameOf(context, user);
    final friend = style == PersonCardStyle.friend;
    final gap = friend ? AppSpacing.lg : AppSpacing.md;
    final card = Material(
      color: AppColors.surfaceContainerLow,
      borderRadius:
          BorderRadius.circular(friend ? AppSpacing.radiusXl : AppRadius.tile),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ??
            (user.deleted
                ? null
                : () => context.push(AppRoutes.userProfile(user.id))),
        child: Padding(
          padding: EdgeInsets.all(friend ? AppSpacing.lg : AppSpacing.md),
          child: Row(
            children: [
              AppAvatar(
                imageUrl: user.deleted ? null : user.avatarUrl,
                displayName: name,
                size: 48,
              ),
              SizedBox(width: gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium
                          .weight(friend ? FontWeight.w800 : FontWeight.w600)
                          .copyWith(
                            color: AppColors.onSurface,
                          ),
                    ),
                    Text(
                      subtitle ??
                          (user.username.isEmpty ? '' : '@${user.username}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[SizedBox(width: gap), trailing!],
            ],
          ),
        ),
      ),
    );
    if (!friend) return card;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: card,
    );
  }
}

/// Small pill action (web `rounded-full px-4 py-1.5 text-xs font-bold`):
/// gradient Accept, surface-container-high Decline / Cancel, tinted Add.
class PeoplePillButton extends StatelessWidget {
  const PeoplePillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.fill = AppColors.surfaceContainerHigh,
    this.fg = AppColors.onSurfaceVariant,
    this.gradient = false,
    this.icon,
  });

  /// Gradient primary pill (Accept).
  const PeoplePillButton.primary({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  })  : fill = null,
        fg = AppColors.onPrimary,
        gradient = true;

  final String label;
  final Color fg;
  final Color? fill;
  final bool gradient;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: AppColors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: gradient ? null : fill,
            gradient: gradient ? AppColors.primaryGradient : null,
            borderRadius: AppSpacing.borderRadiusFull,
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 6,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: fg),
                    AppSpacing.hGapXs,
                  ],
                  Text(
                    label,
                    style: AppTypography.labelMedium.copyWith(color: fg),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Web people tab bar: a surface-container-low pill with pill tabs; the
/// selected tab is white with on-surface text and a small shadow. Works
/// with the ambient [DefaultTabController] (or [controller]).
class PillTabBar extends StatelessWidget implements PreferredSizeWidget {
  const PillTabBar({super.key, required this.tabs, this.controller});

  final List<String> tabs;
  final TabController? controller;

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppSpacing.borderRadiusFull,
      ),
      child: TabBar(
        controller: controller,
        dividerColor: AppColors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppSpacing.borderRadiusFull,
          boxShadow: [
            BoxShadow(
                color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
          ],
        ),
        splashBorderRadius: AppSpacing.borderRadiusFull,
        labelColor: AppColors.onSurface,
        unselectedLabelColor: AppColors.onSurfaceVariant,
        labelStyle: AppTypography.titleSmall,
        unselectedLabelStyle: AppTypography.titleSmall,
        labelPadding: EdgeInsets.zero,
        tabs: [for (final t in tabs) Tab(text: t, height: 36)],
      ),
    );
  }
}
