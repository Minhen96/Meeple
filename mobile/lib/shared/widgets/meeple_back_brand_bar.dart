import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_shadows.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:meeple_hearth/shared/widgets/notification_bell.dart';

/// The web `AppBar` with `showBack` (detail pages such as another user's
/// profile): frosted glass, a plain `arrow_back`, the primary "Meeple"
/// wordmark (or [title]) and the notification bell on the right.
class MeepleBackBrandBar extends StatelessWidget
    implements PreferredSizeWidget {
  const MeepleBackBrandBar({
    super.key,
    this.title,
    this.actions,
    this.fallbackRoute = '/',
    this.showBell = true,
  });

  /// Replaces the "Meeple" wordmark.
  final String? title;

  /// Extra actions before the bell.
  final List<Widget>? actions;

  /// Where back goes after a deep link (nothing to pop).
  final String fallbackRoute;
  final bool showBell;

  @override
  Size get preferredSize => const Size.fromHeight(kMeepleBarHeight);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(boxShadow: AppShadows.bar),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: ColoredBox(
            color: AppColors.glassBackground,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: kMeepleBarHeight,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.lg,
                    right: AppSpacing.lg,
                  ),
                  child: Row(
                    children: [
                      BarIconButton(
                        key: const Key('back-brand-bar-back'),
                        icon: Icons.arrow_back_rounded,
                        tooltip:
                            MaterialLocalizations.of(context).backButtonTooltip,
                        onPressed: () =>
                            meepleGoBack(context, fallbackRoute: fallbackRoute),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            title ?? context.l10n.appName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.brandSmall,
                          ),
                        ),
                      ),
                      ...?actions,
                      if (showBell) const NotificationBell(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
