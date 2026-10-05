import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/push/push_providers.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
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
      _TabItem(l10n.navHome, Icons.home_outlined, Icons.home_rounded),
      _TabItem(
        l10n.navLibrary,
        Icons.library_books_outlined,
        Icons.library_books_rounded,
      ),
      _TabItem(l10n.navEvents, Icons.event_outlined, Icons.event_rounded),
      _TabItem(
        l10n.navProfile,
        Icons.person_outline_rounded,
        Icons.person_rounded,
      ),
    ];
    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: widget.shell),
        ],
      ),
      floatingActionButton: _CreateFab(onPressed: () => showCreateSheet(context)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _GlassBottomBar(
        currentIndex: widget.shell.currentIndex,
        tabs: tabs,
        onTap: _onTabTap,
      ),
    );
  }
}

/// The FAB's create sheet (PLAN §3.8 / GAP §6.6).
Future<void> showCreateSheet(BuildContext context) {
  final l10n = context.l10n;
  final options = [
    (Icons.photo_camera_outlined, l10n.createPost, AppRoutes.createPost),
    (Icons.event_available_outlined, l10n.createEvent, AppRoutes.createEvent),
    (Icons.add_box_outlined, l10n.createAddGame, '${AppRoutes.library}?filter=all'),
    (Icons.group_add_outlined, l10n.createFindMatch, AppRoutes.matching),
  ];
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.surfaceContainerLowest,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (icon, label, route) in options)
              ListTile(
                key: ValueKey('create-$route'),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppSpacing.borderRadiusLg,
                ),
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryFixed,
                  child: Icon(icon, color: AppColors.primary),
                ),
                title: Text(label, style: AppTypography.titleMedium),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  if (route.startsWith(AppRoutes.library)) {
                    context.go(route);
                  } else {
                    context.push(route);
                  }
                },
              ),
          ],
        ),
      ),
    ),
  );
}

class _GlassBottomBar extends StatelessWidget {
  const _GlassBottomBar({
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
  });

  final int currentIndex;
  final List<_TabItem> tabs;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    Widget tab(int i) => Expanded(
          child: _TabButton(
            tab: tabs[i],
            isActive: currentIndex == i,
            onTap: () => onTap(i),
          ),
        );
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 64 + bottomPadding,
          padding: EdgeInsets.only(bottom: bottomPadding),
          color: AppColors.glassBackground,
          child: Row(
            children: [
              tab(0),
              tab(1),
              // Dock for the FAB.
              const SizedBox(width: 72),
              tab(2),
              tab(3),
            ],
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
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusMd,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? tab.activeIcon : tab.icon, size: 24, color: color),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tab.label,
                maxLines: 1,
                style: AppTypography.labelSmall.copyWith(
                  color: color,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateFab extends StatelessWidget {
  const _CreateFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
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
                size: 28,
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
