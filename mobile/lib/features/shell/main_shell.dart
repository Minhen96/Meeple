import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';

/// Root scaffold that wraps all main-tab screens.
///
/// Uses [StatefulNavigationShell] for per-tab back-stack preservation.
/// Bottom nav bar uses the glassmorphism treatment from DESIGN.md §7.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _tabs = [
    _TabItem(
      index: 0,
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    _TabItem(
      index: 1,
      label: 'Library',
      icon: Icons.library_books_outlined,
      activeIcon: Icons.library_books_rounded,
    ),
    _TabItem(
      index: 2,
      label: 'Events',
      icon: Icons.event_outlined,
      activeIcon: Icons.event_rounded,
    ),
    _TabItem(
      index: 3,
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  void _onTabTap(int index) {
    if (shell.currentIndex == index) {
      // Pop to root of this branch on double-tap.
      shell.goBranch(index, initialLocation: true);
    } else {
      shell.goBranch(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      // FAB for creating a post — visible on all main tabs.
      floatingActionButton: _CreatePostFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _GlassBottomBar(
        currentIndex: shell.currentIndex,
        tabs: _tabs,
        onTap: _onTabTap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Glass bottom navigation bar
// ---------------------------------------------------------------------------

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

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          // Extra space in the middle for FAB dock.
          height: 64 + bottomPadding,
          padding: EdgeInsets.only(bottom: bottomPadding),
          decoration: const BoxDecoration(
            color: AppColors.glassBackground,
          ),
          child: Row(
            children: [
              // Left two tabs
              Expanded(
                child: Row(
                  children: tabs
                      .sublist(0, 2)
                      .map(
                        (t) => Expanded(
                          child: _TabButton(
                            tab: t,
                            isActive: currentIndex == t.index,
                            onTap: () => onTap(t.index),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              // FAB dock spacer
              const SizedBox(width: 72),
              // Right two tabs
              Expanded(
                child: Row(
                  children: tabs
                      .sublist(2)
                      .map(
                        (t) => Expanded(
                          child: _TabButton(
                            tab: t,
                            isActive: currentIndex == t.index,
                            onTap: () => onTap(t.index),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: AppSpacing.borderRadiusMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? tab.activeIcon : tab.icon,
                key: ValueKey(isActive),
                size: 24,
                color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tab.label,
              style: AppTypography.labelSmall.copyWith(
                color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Floating action button
// ---------------------------------------------------------------------------

class _CreatePostFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: AppColors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(AppRoutes.createPost),
          child: const Icon(
            Icons.add_rounded,
            color: AppColors.onPrimary,
            size: 28,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data class
// ---------------------------------------------------------------------------

class _TabItem {
  const _TabItem({
    required this.index,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final int index;
  final String label;
  final IconData icon;
  final IconData activeIcon;
}
