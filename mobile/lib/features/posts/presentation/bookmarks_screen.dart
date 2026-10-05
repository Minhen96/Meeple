import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/features/home/presentation/widgets/post_card.dart';
import 'package:meeple_hearth/features/posts/providers/post_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/empty_state.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:meeple_hearth/shared/widgets/status_banners.dart';

/// Saved posts (`GET /users/me/bookmarks`).
class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final saved = ref.watch(bookmarksProvider);
    return Scaffold(
      appBar: MeepleAppBar(
        title: l10n.bookmarksTitle,
        showBackButton: true,
        fallbackRoute: '/profile',
      ),
      body: saved.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(bookmarksProvider),
        ),
        data: (s) => s.items.isEmpty
            ? EmptyState(
                icon: Icons.bookmark_border_rounded,
                title: l10n.bookmarksEmptyTitle,
                subtitle: l10n.bookmarksEmptyBody,
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(bookmarksProvider.future),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.pixels >= n.metrics.maxScrollExtent * 0.8) {
                      ref.read(bookmarksProvider.notifier).loadMore();
                    }
                    return false;
                  },
                  child: ListView.builder(
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
