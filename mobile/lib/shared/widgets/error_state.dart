import 'package:flutter/material.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';

/// Centred error state with message and retry button.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.error,
    this.onRetry,
    this.title,
  });

  final Object error;
  final VoidCallback? onRetry;

  /// Defaults to "Oops!".
  final String? title;

  @override
  Widget build(BuildContext context) {
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
              decoration: BoxDecoration(
                color: AppColors.errorContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                error is NetworkException || error is OfflineException
                    ? Icons.wifi_off_rounded
                    : Icons.error_outline_rounded,
                size: 40,
                color: AppColors.error,
              ),
            ),
            AppSpacing.vGapXl,
            Text(
              title ?? context.l10n.commonOops,
              style: AppTypography.titleLarge,
              textAlign: TextAlign.center,
            ),
            AppSpacing.vGapSm,
            Text(
              localizedError(context.l10n, error),
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              AppSpacing.vGapXl,
              AppButton(
                label: context.l10n.commonRetry,
                onPressed: onRetry,
                minWidth: 160,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
