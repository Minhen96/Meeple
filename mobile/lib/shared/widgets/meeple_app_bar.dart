import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_shadows.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/notification_bell.dart';

/// Height of [MeepleBrandBar] (web: `py-4` + 32px row).
const double kMeepleBarHeight = 64;

/// Height of [MeepleAppBar]: the web sub-page header row (40px) sits 24px
/// below the top (`pt-4` + `mt-3`) with 12px under it.
const double kSubPageHeaderHeight = 76;

/// Pops the current route; with nothing to pop (deep link) goes to
/// [fallbackRoute] — the logical parent (SCREENS §15.1).
void meepleGoBack(BuildContext context, {String fallbackRoute = '/'}) {
  final router = GoRouter.maybeOf(context);
  if (router == null) {
    Navigator.of(context).maybePop();
  } else if (router.canPop()) {
    router.pop();
  } else {
    router.go(fallbackRoute);
  }
}

/// Sub-page header bar — the mobile twin of the web `PageHeader`: a round
/// filled back button (`arrow_back` in a 40px surface-container-low circle)
/// with a bold title beside it, and optional trailing [actions].
///
/// Use as `Scaffold.appBar` on every pushed (non-tab) screen:
/// ```dart
/// appBar: MeepleAppBar(title: l10n.settingsTitle, showBackButton: true),
/// ```
/// With `showBackButton: false` it renders the title alone (no glass) — for
/// main tabs use [MeepleBrandBar] instead.
class MeepleAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MeepleAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.eyebrow,
    this.leading,
    this.actions,
    this.showBackButton = false,
    this.onBack,
    this.centerTitle = false,
    this.fallbackRoute = '/',
    this.backgroundColor = AppColors.background,
    this.bottom,
    this.compactTitle = false,
  });

  final String? title;
  final Widget? titleWidget;

  /// Small uppercase primary line above the title (web `eyebrow`).
  final String? eyebrow;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBack;
  final bool centerTitle;

  /// Logical parent used when there is nothing to pop, e.g. after opening
  /// a deep link (SCREENS §15.1).
  final String fallbackRoute;

  /// Defaults to the page background so the header reads as part of the
  /// page (the web header is not a separate bar).
  final Color backgroundColor;

  /// Optional widget under the header row (e.g. a [TabBar]).
  final PreferredSizeWidget? bottom;

  /// 20px title (web `PageHeader`, nested settings pages) instead of the
  /// 24px title of top-level sub-pages (Settings, Notifications).
  final bool compactTitle;

  @override
  Size get preferredSize => Size.fromHeight(
        kSubPageHeaderHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final lead = showBackButton
        ? CircleBackButton(
            onPressed: onBack ??
                () => meepleGoBack(context, fallbackRoute: fallbackRoute),
          )
        : leading;
    final heading = titleWidget ??
        (title == null
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: centerTitle
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  if (eyebrow != null)
                    Text(
                      eyebrow!.toUpperCase(),
                      style: AppTypography.eyebrow.copyWith(
                        color: AppColors.primary,
                        letterSpacing: 1,
                        height: 1.2,
                      ),
                    ),
                  // Long titles (or a crowded action row) shrink rather
                  // than truncate.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: centerTitle
                        ? Alignment.center
                        : AlignmentDirectional.centerStart,
                    child: Text(
                      title!,
                      // With an eyebrow the pair must fit the 40px row.
                      style: eyebrow != null
                          ? AppTypography.headlineSmall.copyWith(height: 1.2)
                          : compactTitle
                              ? AppTypography.headlineSmall
                              : AppTypography.headlineMedium
                                  .copyWith(letterSpacing: 0),
                      maxLines: 1,
                    ),
                  ),
                ],
              ));
    return Material(
      color: backgroundColor,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: kSubPageHeaderHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: NavigationToolbar(
                  leading: lead,
                  middle: heading,
                  trailing: actions == null
                      ? null
                      : Row(mainAxisSize: MainAxisSize.min, children: actions!),
                  centerMiddle: centerTitle,
                  middleSpacing: AppSpacing.md,
                ),
              ),
            ),
            if (bottom != null) bottom!,
          ],
        ),
      ),
    );
  }
}

/// The web `PageHeader` back button: a 40px filled circle with
/// `arrow_back`. Use it anywhere a sub-page needs "back".
class CircleBackButton extends StatelessWidget {
  const CircleBackButton({
    super.key,
    this.onPressed,
    this.color = AppColors.surfaceContainerLow,
    this.iconColor = AppColors.onSurfaceVariant,
  });

  final VoidCallback? onPressed;

  /// Fill colour; over images use a translucent dark fill
  /// (`AppColors.scrim.withValues(alpha: .3)`) and white [iconColor].
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return CircleIconButton(
      icon: Icons.arrow_back_rounded,
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: onPressed ?? () => meepleGoBack(context),
      color: color,
      iconColor: iconColor,
    );
  }
}

/// A 40px filled round icon button (web `w-10 h-10 rounded-full
/// bg-surface-container-low`). Used for back, "more" and toolbar actions.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color = AppColors.surfaceContainerLow,
    this.iconColor = AppColors.onSurfaceVariant,
    this.size = 40,
    this.iconSize = 22,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color color;
  final Color iconColor;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: color,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: iconSize, color: iconColor),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

/// Inline version of the sub-page header, for screens that scroll the header
/// away with their content (web `PageHeader`): back circle + title.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.trailing,
    this.onBack,
    this.fallbackRoute = '/',
  });

  final String title;
  final String? eyebrow;
  final Widget? trailing;
  final VoidCallback? onBack;
  final String fallbackRoute;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xl),
      child: Row(
        children: [
          CircleBackButton(
            onPressed: onBack ??
                () => meepleGoBack(context, fallbackRoute: fallbackRoute),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null)
                  Text(
                    eyebrow!.toUpperCase(),
                    style: AppTypography.eyebrow.copyWith(
                      color: AppColors.primary,
                      letterSpacing: 1,
                    ),
                  ),
                Text(title, style: AppTypography.headlineSmall),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// The Meeple mark: the app icon on a small white rounded tile tilted
/// -12° (web top bar) — [size] 32 in bars, 64 on the auth hero.
class MeepleLogo extends StatelessWidget {
  const MeepleLogo({super.key, this.size = 32, this.angle = -12});

  final double size;

  /// Tilt in degrees.
  final double angle;

  @override
  Widget build(BuildContext context) {
    final large = size > 40;
    return Transform.rotate(
      angle: angle * math.pi / 180,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.19),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest
              .withValues(alpha: large ? 0.9 : 1),
          borderRadius: BorderRadius.circular(large ? 16 : size / 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: large ? 0.18 : 0.08),
              blurRadius: large ? 40 : 3,
              offset: Offset(0, large ? 20 : 1),
            ),
          ],
        ),
        child: Image.asset(
          'assets/images/meeple_logo.png',
          fit: BoxFit.contain,
          excludeFromSemantics: true,
          errorBuilder: (_, __, ___) => Icon(
            Icons.casino_rounded,
            color: AppColors.primary,
            size: size * 0.6,
          ),
        ),
      ),
    );
  }
}

/// Main-tab top bar (web `AppBar` on Home / Library / Events / Profile):
/// frosted glass, logo + "Meeple" wordmark left, search and the
/// notification bell (with unread badge) right.
///
/// ```dart
/// appBar: const MeepleBrandBar(),
/// appBar: MeepleBrandBar(actions: [IconButton(...)]), // extra, before search
/// ```
class MeepleBrandBar extends StatelessWidget implements PreferredSizeWidget {
  const MeepleBrandBar({
    super.key,
    this.actions,
    this.showSearch = true,
    this.bottom,
  });

  /// Screen-specific actions shown before search and the bell.
  final List<Widget>? actions;
  final bool showSearch;

  /// Optional widget under the bar row (e.g. a [TabBar]); it shares the glass.
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(
        kMeepleBarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: const BoxDecoration(boxShadow: AppShadows.bar),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: ColoredBox(
            color: AppColors.glassBackground,
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: kMeepleBarHeight,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: AppSpacing.xl,
                        right: AppSpacing.lg,
                      ),
                      child: Row(
                        children: [
                          const MeepleLogo(),
                          const SizedBox(width: 10),
                          Semantics(
                            header: true,
                            child: Text(
                              l10n.appName,
                              style: AppTypography.brandSmall,
                            ),
                          ),
                          const Spacer(),
                          ...?actions,
                          if (showSearch)
                            BarIconButton(
                              key: const Key('top-bar-search'),
                              icon: Icons.search_rounded,
                              tooltip: l10n.commonSearch,
                              onPressed: () => context.push(AppRoutes.search),
                            ),
                          const NotificationBell(),
                        ],
                      ),
                    ),
                  ),
                  if (bottom != null) bottom!,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Plain 24px on-surface-variant icon with a 40px tap target — the icon
/// style of the web top bar. Use for actions in [MeepleBrandBar] /
/// [MeepleAppBar].
class BarIconButton extends StatelessWidget {
  const BarIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color = AppColors.onSurfaceVariant,
    this.child,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color color;

  /// Replaces the icon (e.g. an icon wrapped in a [Badge]).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      iconSize: 24,
      color: color,
      icon: child ?? Icon(icon),
    );
  }
}
