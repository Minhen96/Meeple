import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';

/// Glass-morphism app bar used across all main screens.
///
/// Uses [PreferredSizeWidget] so it integrates with [Scaffold.appBar].
/// Automatically applies the frosted-glass effect from DESIGN.md §7.
class MeepleAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MeepleAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.actions,
    this.showBackButton = false,
    this.onBack,
    this.centerTitle = false,
  });

  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBack;
  final bool centerTitle;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: AppBar(
          backgroundColor: AppColors.glassBackground,
          surfaceTintColor: AppColors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: centerTitle,
          leading: showBackButton
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                )
              : leading,
          title: titleWidget ??
              (title != null
                  ? Text(title!, style: AppTypography.titleLarge)
                  : null),
          actions: actions,
        ),
      ),
    );
  }
}

/// The branded "Meeple" wordmark used on the home app bar.
class MeepleBrandBar extends StatelessWidget implements PreferredSizeWidget {
  const MeepleBrandBar({super.key, this.actions});

  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return MeepleAppBar(
      titleWidget: Text('Meeple', style: AppTypography.brandSmall),
      actions: actions,
    );
  }
}
