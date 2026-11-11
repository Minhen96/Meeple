import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/l10n/l10n.dart';

/// The bottom-nav "+" sheet (PLAN §3.8, web `CreateSheet`): a "Create"
/// title over a 2×2 grid of Post / Event / Add Game / Find Match cards,
/// each with a round secondary-container icon, a bold label and a hint.
Future<void> showCreateActionsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (sheetContext) => CreateSheet(
      onSelected: (route) {
        Navigator.of(sheetContext).pop();
        if (route.startsWith(AppRoutes.library)) {
          context.go(route);
        } else {
          context.push(route);
        }
      },
    ),
  );
}

class CreateSheet extends StatelessWidget {
  const CreateSheet({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final actions = [
      (
        Icons.add_photo_alternate_outlined,
        l10n.createSheetPost,
        l10n.createSheetPostHint,
        AppRoutes.createPost,
      ),
      (
        Icons.event_outlined,
        l10n.createSheetEvent,
        l10n.createSheetEventHint,
        AppRoutes.createEvent,
      ),
      (
        Icons.library_add_outlined,
        l10n.createSheetGame,
        l10n.createSheetGameHint,
        '${AppRoutes.library}?filter=all',
      ),
      (
        Icons.group_add_outlined,
        l10n.createSheetMatch,
        l10n.createSheetMatchHint,
        AppRoutes.matching,
      ),
    ];
    Widget card(int i) {
      final (icon, label, hint, route) = actions[i];
      return Expanded(
        child: Material(
          color: AppColors.surfaceContainerLow,
          borderRadius: AppSpacing.borderRadiusLg,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('create-$route'),
            onTap: () => onSelected(route),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 22,
                      color: AppColors.onSecondaryContainer,
                    ),
                  ),
                  AppSpacing.vGapSm,
                  Text(label, style: AppTypography.titleMedium),
                  AppSpacing.vGapSm,
                  Text(
                    hint,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget row(int a) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [card(a), AppSpacing.hGapMd, card(a + 1)],
          ),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Web handle: 40×6 surface-container-highest pill.
            Center(
              child: Container(
                width: 40,
                height: 6,
                margin: const EdgeInsets.only(
                  top: AppSpacing.md,
                  bottom: AppSpacing.lg,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerHighest,
                  borderRadius: AppSpacing.borderRadiusFull,
                ),
              ),
            ),
            Text(
              l10n.createTitle,
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            AppSpacing.vGapLg,
            row(0),
            AppSpacing.vGapMd,
            row(2),
          ],
        ),
      ),
    );
  }
}
