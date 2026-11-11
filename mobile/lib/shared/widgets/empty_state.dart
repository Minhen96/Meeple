import 'package:flutter/material.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';

/// Centred empty-state with icon, title, subtitle and optional CTA.
///
/// [boxed] renders the web in-page variant: a rounded-2xl
/// surface-container-low panel (`px-6 py-12`), a plain 48px icon and a
/// small gradient pill button.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.boxed = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    if (boxed) return _buildBoxed();
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.xxxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            AppSpacing.vGapXl,
            Text(
              title,
              style: AppTypography.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              AppSpacing.vGapSm,
              Text(
                subtitle!,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              AppSpacing.vGapXl,
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                minWidth: 200,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBoxed() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxxl,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppSpacing.borderRadiusLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.primary),
          AppSpacing.vGapMd,
          Text(
            title,
            style: AppTypography.titleLarge,
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            AppSpacing.vGapMd,
            Text(
              subtitle!,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            AppSpacing.vGapMd,
            AppButton(
              label: actionLabel!,
              onPressed: onAction,
              minWidth: 0,
              size: AppButtonSize.sm,
            ),
          ],
        ],
      ),
    );
  }
}
