import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/models/user_summary.dart';
import 'package:meeple_hearth/shared/widgets/app_avatar.dart';

/// Display name of [user], or "Deleted User" for soft-deleted accounts
/// (FEATURES §1.6).
String displayNameOf(BuildContext context, UserSummary user) =>
    user.deleted ? context.l10n.commonDeletedUser : user.displayName;

/// Avatar + display name + @username row (tap opens the profile).
class UserRow extends StatelessWidget {
  const UserRow({
    super.key,
    required this.user,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.avatarSize = AvatarSize.md,
  });

  final UserSummary user;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    final name = displayNameOf(context, user);
    return InkWell(
      borderRadius: AppSpacing.borderRadiusLg,
      onTap: onTap ??
          (user.deleted ? null : () => context.push('/profile/${user.id}')),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            AppAvatar(
              imageUrl: user.deleted ? null : user.avatarUrl,
              displayName: name,
              size: avatarSize,
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTypography.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle ?? (user.username.isEmpty ? '' : '@${user.username}'),
                    style: AppTypography.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[AppSpacing.hGapSm, trailing!],
          ],
        ),
      ),
    );
  }
}

/// Overlapping avatars with a "+N" chip (DESIGN.md avatar stack).
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.users,
    this.size = 24,
    this.max = 4,
  });

  final List<UserSummary> users;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) return const SizedBox.shrink();
    final shown = users.take(max).toList();
    final extra = users.length - shown.length;
    final count = shown.length + (extra > 0 ? 1 : 0);
    final step = size * 0.7;
    return SizedBox(
      height: size + 4,
      width: step * (count - 1) + size + 4,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * step,
              child: AppAvatar(
                imageUrl: shown[i].avatarUrl,
                displayName: shown[i].displayName,
                size: size,
                borderColor: AppColors.surfaceContainerLow,
              ),
            ),
          if (extra > 0)
            Positioned(
              left: shown.length * step,
              child: Container(
                width: size + 4,
                height: size + 4,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '+$extra',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
