import 'package:flutter/material.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';

/// One action in [showProfileActionSheet].
typedef ProfileSheetAction = ({
  String id,
  IconData icon,
  String label,
  bool danger,
});

/// Web profile "···" bottom sheet: a column of full-width pill buttons
/// (secondary, danger for destructive ones). Resolves to the chosen id.
Future<String?> showProfileActionSheet(
  BuildContext context, {
  required List<ProfileSheetAction> actions,
  String keyPrefix = 'profile-menu',
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusXxl),
      ),
    ),
    builder: (sheet) => SafeArea(
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
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) AppSpacing.vGapSm,
              AppButton(
                key: ValueKey('$keyPrefix-${actions[i].id}'),
                label: actions[i].label,
                icon: actions[i].icon,
                variant: actions[i].danger
                    ? AppButtonVariant.danger
                    : AppButtonVariant.secondary,
                onPressed: () => Navigator.of(sheet).pop(actions[i].id),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// The round "···" button beside the profile's main action (web
/// `w-11 h-11 rounded-full bg-surface-container-high`).
class ProfileMoreButton extends StatelessWidget {
  const ProfileMoreButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
  });

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CircleIconButton(
        icon: Icons.more_horiz_rounded,
        tooltip: tooltip,
        onPressed: onPressed,
        color: AppColors.surfaceContainerHigh,
        iconColor: AppColors.onSurfaceVariant,
        size: 44,
      );
}
