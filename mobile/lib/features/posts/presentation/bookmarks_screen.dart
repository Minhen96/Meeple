import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/features/home/presentation/widgets/post_card.dart';
import 'package:meeple_hearth/features/posts/providers/post_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:meeple_hearth/shared/widgets/skeleton_widget.dart';
import 'package:meeple_hearth/shared/widgets/status_banners.dart';

/// Saved posts (`GET /users/me/bookmarks`, web `/posts/saved`): circle back
/// + title, the saved post cards, or a boxed empty note. Un-saving a post
/// here drops it from the list.
class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final saved = ref.watch(bookmarksProvider);
    return Scaffold(
      appBar: MeepleAppBar(
        title: l10n.bookmarksTitle,
        compactTitle: true,
        leading: CircleBackButton(
          color: AppColors.surfaceContainerHigh,
          onPressed: () => meepleGoBack(context, fallbackRoute: '/profile'),
        ),
      ),
      body: saved.when(
        loading: () => ListView(
          children: const [PostCardSkeleton(), PostCardSkeleton()],
        ),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(bookmarksProvider),
        ),
        data: (s) => RefreshIndicator(
          onRefresh: () => ref.refresh(bookmarksProvider.future),
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels >= n.metrics.maxScrollExtent * 0.8) {
                ref.read(bookmarksProvider.notifier).loadMore();
              }
              return false;
            },
            child: s.items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      Container(
                        key: const Key('saved-empty'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                          vertical: AppSpacing.xxxl,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: AppSpacing.borderRadiusLg,
                        ),
                        child: Text(
                          l10n.savedEmpty,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    itemCount: s.items.length + 1,
                    itemBuilder: (_, i) => i == s.items.length
                        ? ListFooter(
                            isLoading: s.isLoadingMore,
                            hasMore: s.hasMore,
                            error: s.loadMoreError,
                            onRetry: () =>
                                ref.read(bookmarksProvider.notifier).loadMore(),
                          )
                        : PostCard(post: s.items[i]),
                  ),
          ),
        ),
      ),
    );
  }
}
