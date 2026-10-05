import 'package:flutter/material.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/l10n/l10n.dart';

enum ToastType { success, error, info }

/// Snackbar toast per SCREENS §14.1: success 3s (tertiary), error 5s (error),
/// info 3s (inverse surface).
void showToast(
  BuildContext context,
  String message, {
  ToastType type = ToastType.info,
}) {
  final (bg, fg) = switch (type) {
    ToastType.success => (AppColors.tertiary, AppColors.onTertiary),
    ToastType.error => (AppColors.error, AppColors.onError),
    ToastType.info => (AppColors.inverseSurface, AppColors.inverseOnSurface),
  };
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: bg,
        duration: Duration(seconds: type == ToastType.error ? 5 : 3),
        shape: const RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusLg,
        ),
        content: Text(
          message,
          style: AppTypography.bodyMedium.copyWith(color: fg),
        ),
      ),
    );
}

/// Shows the localised message for [error] as an error toast.
void showErrorToast(BuildContext context, Object error) =>
    showToast(context, localizedError(context.l10n, error),
        type: ToastType.error);
