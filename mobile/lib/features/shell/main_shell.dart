import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_shadows.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/push/push_providers.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/shell/create_sheet.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/status_banners.dart';

/// Root scaffold of the four main tabs.
///
/// [StatefulNavigationShell] keeps one back stack per tab; the bottom bar
/// uses the glass treatment (DESIGN.md §7) with the centre FAB opening the
/// create sheet (Post / Event / Add Game / Find Match).
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrePrompt());
  }

  /// Shows the push pre-permission screen once (MOBILE_FLUTTER §8).
  Future<void> _maybePrePrompt() async {
    final push = ref.read(pushServiceProvider);
    if (!await push.shouldShowPrePrompt() || !mounted) return;
    await context.push(AppRoutes.pushPermission);
  }

  void _onTabTap(int index) => widget.shell.goBranch(
        index,
        // Re-tapping the active tab pops it to its root.
        initialLocation: index == widget.shell.currentIndex,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tabs = [
      // Material Symbols names of the web nav: home, menu_book, event, person.
      _TabItem(l10n.navHome, Icons.home_outlined, Icons.home),
      _TabItem(l10n.navLibrary, Icons.menu_book_outlined, Icons.menu_book),
      _TabItem(l10n.navEvents, Icons.event_outlined, Icons.event),
      _TabItem(l10n.navProfile, Icons.person_outline, Icons.person),
    ];
    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: widget.shell),
        ],
      ),
      floatingActionButton: _CreateFab(onPressed: () => showCreateSheet(context)),
      floatingActionButtonLocation: const _CreateFabLocation(),
      bottomNavigationBar: _GlassBottomBar(
        currentIndex: widget.shell.currentIndex,
        tabs: tabs,
        onTap: _onTabTap,
      ),
    );
  }
}

/// The FAB's create sheet (PLAN §3.8 / GAP §6.6) — see [CreateSheet].
Future<void> showCreateSheet(BuildContext context) =>
    showCreateActionsSheet(context);

/// Bottom navigation (web `BottomNav.svelte`): frosted surface with a
/// rounded top (`rounded-t-[2rem]`), a soft upward shadow, and pill tabs —
/// the active tab gets a primary-container/20 pill and a filled icon.
class _GlassBottomBar extends StatelessWidget {
  const _GlassBottomBar({
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
  });

  final int currentIndex;
  final List<_TabItem> tabs;
  final ValueChanged<int> onTap;

  static const _radius = BorderRadius.vertical(
    top: Radius.circular(AppRadius.panel),
  );

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    Widget tab(int i) => _TabButton(
          tab: tabs[i],
          isActive: currentIndex == i,
          onTap: () => onTap(i),
        );
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: _radius,
        boxShadow: AppShadows.nav,
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            color: AppColors.glassBackground,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              bottomPadding,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                tab(0),
                tab(1),
                // Room for the create button, which floats above the bar.
                const SizedBox(width: 56),
                tab(2),
                tab(3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  final _TabItem tab;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : AppColors.onSurfaceVariant;
    return Semantics(
      selected: isActive,
      button: true,
      label: tab.label,
      excludeSemantics: true,
      child: Material(
        color: isActive
            ? AppColors.primaryContainer.withValues(alpha: 0.2)
            : AppColors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isActive ? tab.activeIcon : tab.icon, size: 24, color: color),
                const SizedBox(height: 2),
                Text(
                  tab.label,
                  maxLines: 1,
                  style: AppTypography.labelSmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Places the create button like the web (`-mt-8` inside the nav row): its
/// centre sits 25px below the top edge of the bottom bar, so it pokes out
/// above the bar by about half its height.
class _CreateFabLocation extends FloatingActionButtonLocation {
  const _CreateFabLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry g) => Offset(
        (g.scaffoldSize.width - g.floatingActionButtonSize.width) / 2,
        g.contentBottom + 25 - g.floatingActionButtonSize.height / 2,
      );
}

class _CreateFab extends StatelessWidget {
  const _CreateFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradientDiagonal,
        shape: BoxShape.circle,
        boxShadow: AppShadows.primaryGlow,
      ),
      child: SizedBox(
        width: 56,
        height: 56,
        child: Material(
          color: AppColors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('create-fab'),
            onTap: onPressed,
            child: Tooltip(
              message: context.l10n.createTitle,
              child: const Icon(
                Icons.add_rounded,
                color: AppColors.onPrimary,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  const _TabItem(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}
