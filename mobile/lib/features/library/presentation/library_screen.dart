import 'package:flutter/material.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:meeple_hearth/shared/widgets/skeleton_widget.dart';

/// Game library screen — Phase 1 stub.
///
/// Shows the user's owned, wishlisted, and favourited games.
/// Tabs: Owned | Wishlist | Favourites.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: MeepleAppBar(
          title: 'My Library',
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Add game',
              onPressed: () {},
            ),
          ],
        ),
        body: Column(
          children: [
            _LibraryTabBar(),
            Expanded(
              child: TabBarView(
                children: [
                  _GameGrid(),
                  _GameGrid(),
                  _GameGrid(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryTabBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: TabBar(
        tabs: const [
          Tab(text: 'OWNED'),
          Tab(text: 'WISHLIST'),
          Tab(text: 'FAVOURITES'),
        ],
        labelStyle: AppTypography.labelMedium.copyWith(
          color: AppColors.primary,
        ),
        unselectedLabelStyle: AppTypography.labelMedium,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
      ),
    );
  }
}

class _GameGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.72,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => const GameCardSkeleton(),
    );
  }
}
