import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/events/domain/event_model.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/features/library/presentation/widgets/library_widgets.dart';
import 'package:meeple_hearth/features/search/data/search_repository.dart';
import 'package:meeple_hearth/features/search/providers/search_provider.dart';
import 'package:meeple_hearth/features/social/presentation/friend_button.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/models/user_summary.dart';
import 'package:meeple_hearth/shared/widgets/app_avatar.dart';
import 'package:meeple_hearth/shared/widgets/skeleton_widget.dart';
import 'package:meeple_hearth/shared/widgets/user_widgets.dart';

/// Unified search (web `/search`): games, players and events, 400 ms
/// debounce, recent searches when the input is empty.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    setState(() {});
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

  void _clear() {
    _controller.clear();
    _debounce?.cancel();
    setState(() => _query = '');
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shape = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      borderSide: BorderSide.none,
    );
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                28,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('search-input'),
                      controller: _controller,
                      focusNode: _focus,
                      autofocus: true,
                      onChanged: _onChanged,
                      textInputAction: TextInputAction.search,
                      style: AppTypography.bodyMedium,
                      decoration: InputDecoration(
                        hintText: l10n.searchPlaceholder,
                        hintStyle: AppTypography.bodyMedium.copyWith(
                          color:
                              AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                        filled: true,
                        fillColor: AppColors.surfaceContainerHighest,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 15),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 24,
                          color: AppColors.onSurfaceVariant,
                        ),
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 44),
                        suffixIcon: _controller.text.isEmpty
                            ? null
                            : IconButton(
                                key: const Key('search-clear'),
                                tooltip: l10n.searchClearInput,
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: AppColors.onSurfaceVariant,
                                ),
                                onPressed: _clear,
                              ),
                        border: shape,
                        enabledBorder: shape,
                        focusedBorder: shape.copyWith(
                          borderSide: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton(
                    key: const Key('search-close'),
                    tooltip: l10n.searchCloseLabel,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.onSurfaceVariant,
                    ),
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go(AppRoutes.home),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _query.isEmpty
                  ? _Recent(onPick: _useRecent)
                  : _Results(query: _query),
            ),
          ],
        ),
      ),
    );
  }
}

/// `text-xs font-bold uppercase tracking-widest` group heading.
class _GroupHeading extends StatelessWidget {
  const _GroupHeading(this.text, {this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(text.toUpperCase(), style: AppTypography.overline),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

/// Centered `text-sm` line (`mt-12`).
class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xxxl - AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      );
}

class _Recent extends ConsumerWidget {
  const _Recent({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final recent = ref.watch(recentSearchesProvider).valueOrNull ?? const [];
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      children: [
        if (recent.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          _GroupHeading(
            l10n.searchRecent,
            trailing: GestureDetector(
              key: const Key('search-recent-clear'),
              onTap: () => ref.read(recentSearchesProvider.notifier).clear(),
              child: Text(
                l10n.searchClear,
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          for (final q in recent)
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.tile),
              onTap: () => onPick(q),
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Row(
                  children: [
                    const Icon(
                      Icons.history_rounded,
                      size: 18,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(q, style: AppTypography.bodyMedium),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.searchRemoveRecent(q),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.onSurfaceVariant,
                      ),
                      onPressed: () =>
                          ref.read(recentSearchesProvider.notifier).remove(q),
                    ),
                  ],
                ),
              ),
            ),
        ],
        _Hint(l10n.searchEmptyPrompt),
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
      error: (e, _) => ListView(
        children: [
          _Hint(l10n.searchFailed),
          Center(
            child: TextButton(
              onPressed: () => ref.invalidate(searchResultsProvider(query)),
              child: Text(l10n.commonRetry),
            ),
          ),
        ],
      ),
      data: (r) => r.isEmpty
          ? ListView(children: [_Hint(l10n.searchNoResults(query))])
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
    final groups = <Widget>[
      if (results.games.isNotEmpty)
        _Group(
          title: l10n.searchGames,
          children: [for (final g in results.games) _GameRow(game: g)],
        ),
      if (results.users.isNotEmpty)
        _Group(
          title: l10n.searchPlayers,
          children: [for (final u in results.users) _UserRow(user: u)],
        ),
      if (results.events.isNotEmpty)
        _Group(
          title: l10n.searchEvents,
          children: [for (final e in results.events) _EventRow(event: e)],
        ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        for (final (i, g) in groups.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xl),
          g,
        ],
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GroupHeading(title),
          for (final (i, c) in children.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.xs),
            c,
          ],
        ],
      );
}

/// `flex items-center gap-3 rounded-xl p-2` result row.
class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(AppRadius.tile),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              leading,
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleSmall,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall,
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
        ),
      );
}

class _GameRow extends StatelessWidget {
  const _GameRow({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) => _Row(
        key: ValueKey('search-game-${game.id}'),
        leading: ClipOval(
          child: SizedBox(
            width: 48,
            height: 48,
            child: SafeNetworkImage(
              url: game.coverUrl,
              fallback: const ColoredBox(
                color: AppColors.surfaceContainer,
                child: Icon(
                  Icons.casino_outlined,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        title: game.name,
        subtitle: game.yearPublished?.toString(),
        onTap: () => context.push(AppRoutes.gameDetail(game.id)),
      );
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user});

  final UserSummary user;

  @override
  Widget build(BuildContext context) {
    final name = displayNameOf(context, user);
    return _Row(
      leading: AppAvatar(imageUrl: user.avatarUrl, displayName: name, size: 48),
      title: name,
      subtitle: user.username.isEmpty ? null : '@${user.username}',
      onTap: user.deleted ? null : () => context.push('/profile/${user.id}'),
      trailing: FriendButton(
        userId: user.id,
        compact: true,
        initial: user.friendshipStatus,
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final when = DateFormat.MMMEd().format(event.scheduledAt.toLocal());
    final game = event.game?.name;
    return _Row(
      leading: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: AppColors.secondaryContainer,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.event_rounded,
          color: AppColors.onSecondaryContainer,
        ),
      ),
      title: event.title,
      subtitle: game == null ? when : '$when · $game',
      onTap: () => context.push(AppRoutes.eventDetail(event.id)),
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
            for (var g = 0; g < 3; g++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonBox(width: 64, height: 12),
                    for (var i = 0; i < 2; i++)
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.md),
                        child: Row(
                          children: [
                            SkeletonCircle(size: 48),
                            AppSpacing.hGapMd,
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SkeletonBox(width: 128, height: 12),
                                SizedBox(height: AppSpacing.sm),
                                SkeletonBox(width: 80, height: 10),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
}
