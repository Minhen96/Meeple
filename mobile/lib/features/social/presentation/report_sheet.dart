import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/features/social/domain/social_model.dart';
import 'package:meeple_hearth/features/social/providers/social_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';

/// Lets the user pick a reason and files `POST /reports`.
/// [targetType] is `user` | `post` | `comment`.
Future<void> showReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required String targetType,
  required String targetId,
}) async {
  final l10n = context.l10n;
  final reason = await showModalBottomSheet<ReportReason>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.surfaceContainerLowest,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            child: Text(l10n.reportTitle, style: AppTypography.titleLarge),
          ),
          for (final r in ReportReason.values)
            ListTile(
              key: ValueKey('report-${r.name}'),
              title: Text(_label(l10n, r)),
              onTap: () => Navigator.of(sheetContext).pop(r),
            ),
          AppSpacing.vGapMd,
        ],
      ),
    ),
  );
  if (reason == null || !context.mounted) return;
  try {
    await ref.read(reportActionsProvider).report(
          targetType: targetType,
          targetId: targetId,
          reason: reason,
        );
    if (context.mounted) {
      showToast(context, l10n.reportSent, type: ToastType.success);
    }
  } catch (e) {
    if (context.mounted) showErrorToast(context, e);
  }
}

String _label(AppLocalizations l10n, ReportReason r) => switch (r) {
      ReportReason.spam => l10n.reportReasonSpam,
      ReportReason.harassment => l10n.reportReasonHarassment,
      ReportReason.inappropriate => l10n.reportReasonInappropriate,
      ReportReason.other => l10n.reportReasonOther,
    };
