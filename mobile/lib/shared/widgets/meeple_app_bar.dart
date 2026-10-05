import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/l10n/l10n.dart';

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
    this.fallbackRoute = '/',
  });

  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBack;
  final bool centerTitle;

  /// Logical parent used when there is nothing to pop, e.g. after opening
  /// a deep link (SCREENS §15.1).
  final String fallbackRoute;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  void _back(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      Navigator.of(context).maybePop();
    } else if (router.canPop()) {
      router.pop();
    } else {
      router.go(fallbackRoute);
    }
  }

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
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: onBack ?? () => _back(context),
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
  const MeepleBrandBar({super.key, this.actions, this.leading});

  final List<Widget>? actions;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return MeepleAppBar(
      titleWidget: Text(context.l10n.appName, style: AppTypography.brandSmall),
      centerTitle: leading != null,
      leading: leading,
      actions: actions,
    );
  }
}
