import 'package:flutter/material.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';

/// Variants of the chip component.
enum AppChipVariant { primary, secondary, tertiary, neutral, error }

/// A compact label chip used for status, tags, and categories.
///
/// Follows the No-Line Rule — no border, depth through background tonal shift.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.variant = AppChipVariant.neutral,
    this.onTap,
    this.isSelected = false,
    this.icon,
  });

  final String label;
  final AppChipVariant variant;
  final VoidCallback? onTap;
  final bool isSelected;
  final IconData? icon;

  Color get _backgroundColor {
    if (isSelected) return AppColors.primaryFixed;
    return switch (variant) {
      AppChipVariant.primary => AppColors.primaryFixed,
      AppChipVariant.secondary => AppColors.secondaryFixed,
      AppChipVariant.tertiary => AppColors.tertiaryFixed,
      AppChipVariant.neutral => AppColors.surfaceContainerHigh,
      AppChipVariant.error => AppColors.errorContainer,
    };
  }

  Color get _textColor => switch (variant) {
        AppChipVariant.primary => AppColors.onPrimaryFixed,
        AppChipVariant.secondary => AppColors.onSecondaryFixed,
        AppChipVariant.tertiary => AppColors.onTertiaryFixed,
        AppChipVariant.neutral => AppColors.onSurfaceVariant,
        AppChipVariant.error => AppColors.onErrorContainer,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: AppSpacing.chipPadding,
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: AppSpacing.borderRadiusFull,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: _textColor),
              AppSpacing.hGapXs,
            ],
            Text(
              label.toUpperCase(),
              style: AppTypography.labelMedium.copyWith(color: _textColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// Amber-tinted friend-status chip.
class FriendStatusChip extends StatelessWidget {
  const FriendStatusChip.pending({super.key}) : _status = 'PENDING';
  const FriendStatusChip.friends({super.key}) : _status = 'FRIENDS';

  final String _status;

  @override
  Widget build(BuildContext context) {
    final isPending = _status == 'PENDING';
    return AppChip(
      label: isPending ? 'Pending' : 'Friends',
      variant: isPending ? AppChipVariant.secondary : AppChipVariant.primary,
    );
  }
}
