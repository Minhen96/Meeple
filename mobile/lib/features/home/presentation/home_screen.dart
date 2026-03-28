import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:meeple_hearth/shared/widgets/skeleton_widget.dart';

/// Home / Feed screen — Phase 1 stub.
///
/// Displays the social feed of posts from friends and the community.
/// Full implementation wires up the feed provider and infinite scroll.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MeepleBrandBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search',
            onPressed: () => context.push(AppRoutes.search),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifications',
            onPressed: () => context.push(AppRoutes.notifications),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.only(top: AppSpacing.md, bottom: 96),
        itemCount: 5,
        separatorBuilder: (_, __) => const Divider(
          color: AppColors.outlineVariant,
          height: 1,
        ),
        itemBuilder: (_, __) => const PostCardSkeleton(),
      ),
    );
  }
}
