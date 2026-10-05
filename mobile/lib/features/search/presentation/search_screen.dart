import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/events/presentation/widgets/event_card.dart';
import 'package:meeple_hearth/features/library/presentation/widgets/game_card.dart';
import 'package:meeple_hearth/features/search/data/search_repository.dart';
import 'package:meeple_hearth/features/search/providers/search_provider.dart';
import 'package:meeple_hearth/features/social/presentation/friend_button.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';
import 'package:meeple_hearth/shared/widgets/skeleton_widget.dart';
import 'package:meeple_hearth/shared/widgets/status_banners.dart';
import 'package:meeple_hearth/shared/widgets/user_widgets.dart';

/// Unified search (SCREENS §13): games, players and events, 400 ms
/// debounce, recent searches when the input is empty.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
      if (_query.length >= 2) {
        ref.read(recentSearchesProvider.notifier).add(_query);
      }
    });
  }

  void _useRecent(String q) {
    _controller.text = q;
    _controller.selection = TextSelection.collapsed(offset: q.length);
    _debounce?.cancel();
    setState(() => _query = q);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.glassBackground,
        titleSpacing: 0,
        title: TextField(
          key: const Key('search-input'),
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            prefixIcon: const Icon(Icons.search_rounded),
          ),
        ),
        actions: [
          IconButton(
            tooltip: l10n.commonClose,
            icon: const Icon(Icons.close_rounded),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go(AppRoutes.home),
          ),
        ],
      ),
      body: _query.isEmpty ? _Recent(onPick: _useRecent) : _Results(query: _query),
    );
  }
}

class _Recent extends ConsumerWidget {
  const _Recent({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final recent = ref.watch(recentSearchesProvider).valueOrNull ?? const [];
    return ListView(
      children: [
        if (recent.isNotEmpty)
          SectionHeader(
            title: l10n.searchRecent,
            actionLabel: l10n.searchClear,
            onAction: () => ref.read(recentSearchesProvider.notifier).clear(),
          ),
        for (final q in recent)
          ListTile(
            leading: const Icon(Icons.history_rounded),
            title: Text(q),
            onTap: () => onPick(q),
            trailing: IconButton(
              tooltip: l10n.commonDelete,
              icon: const Icon(Icons.close_rounded),
              onPressed: () => ref.read(recentSearchesProvider.notifier).remove(q),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Text(
            l10n.searchEmptyPrompt,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final results = ref.watch(searchResultsProvider(query));
    return results.when(
      loading: () => const _ResultsSkeleton(),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () => ref.invalidate(searchResultsProvider(query)),
      ),
      data: (r) => r.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Text(
                  l10n.searchNoResults(query),
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyLarge,
                ),
              ),
            )
          : _ResultsList(results: r),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.results});

  final SearchResults results;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        if (results.games.isNotEmpty) ...[
          SectionHeader(title: l10n.searchGames),
          for (final g in results.games)
            GameListTile(
              game: g,
              subtitle: g.yearPublished?.toString(),
              onTap: () => context.push(AppRoutes.gameDetail(g.id)),
            ),
        ],
        if (results.users.isNotEmpty) ...[
          SectionHeader(title: l10n.searchPlayers),
          for (final u in results.users)
            UserRow(
              user: u,
              trailing: FriendButton(userId: u.id, compact: true, initial: u.friendshipStatus),
            ),
        ],
        if (results.events.isNotEmpty) ...[
          SectionHeader(title: l10n.searchEvents),
          for (final e in results.events) EventCard(event: e),
        ],
      ],
    );
  }
}

class _ResultsSkeleton extends StatelessWidget {
  const _ResultsSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonShimmer(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            for (var i = 0; i < 6; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: [
                    SkeletonCircle(size: 48),
                    AppSpacing.hGapMd,
                    Expanded(child: SkeletonBox(height: 16)),
                  ],
                ),
              ),
          ],
        ),
      );
}
