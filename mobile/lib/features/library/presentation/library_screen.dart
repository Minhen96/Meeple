import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/library/data/game_repository.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/features/library/domain/user_game_model.dart';
import 'package:meeple_hearth/features/library/presentation/widgets/library_sheets.dart';
import 'package:meeple_hearth/features/library/presentation/widgets/library_widgets.dart';
import 'package:meeple_hearth/features/library/providers/library_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:meeple_hearth/shared/widgets/skeleton_widget.dart';
import 'package:meeple_hearth/shared/widgets/status_banners.dart';

/// Library (web `/library`): All Games | My Collection | Wishlist |
/// Favorites tabs over a search ribbon with filter and sort buttons; the
/// All Games tab shows the Game of the Week and the catalogue feed.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key, this.initialTab});

  /// `all` | `collection` | `wishlist` | `favorites`.
  final String? initialTab;

  static int tabIndexOf(String? name) => switch (name) {
        'collection' || 'owned' => 1,
        'wishlist' || 'wishlisted' => 2,
        'favorites' || 'favorited' => 3,
        _ => 0,
      };

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 4,
    vsync: this,
    initialIndex: LibraryScreen.tabIndexOf(widget.initialTab),
  )..addListener(_onTabChanged);
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  int _lastTab = LibraryScreen.tabIndexOf(null);

  /// Filters and sort of the catalogue feed (search text is [_query]).
  GameBrowseQuery _browse = const GameBrowseQuery();

  @override
  void initState() {
    super.initState();
    _lastTab = _tabs.index;
  }

  @override
  void didUpdateWidget(covariant LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _tabs.animateTo(LibraryScreen.tabIndexOf(widget.initialTab));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  /// Switching tabs clears the search, like the web.
  void _onTabChanged() {
    if (_tabs.index == _lastTab) return;
    _lastTab = _tabs.index;
    _debounce?.cancel();
    if (_search.text.isEmpty && _query.isEmpty) {
      setState(() {});
      return;
    }
    _search.clear();
    setState(() => _query = '');
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  Future<void> _openFilters() async {
    if (_tabs.index != 0) _tabs.animateTo(0);
    final next = await showLibraryFilterSheet(context, _browse);
    if (next != null && mounted) setState(() => _browse = next);
  }

  Future<void> _openSort() async {
    if (_tabs.index != 0) _tabs.animateTo(0);
    final picked = await showLibrarySortSheet(context, _browse.sort);
    if (picked != null && mounted) {
      setState(() => _browse = _browse.copyWith(sort: () => picked.$1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onAll = _tabs.index == 0;
    return Scaffold(
      appBar: const MeepleBrandBar(),
      body: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.95),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                children: [
                  _UnderlineTabs(
                    controller: _tabs,
                    labels: [
                      l10n.libraryTabAll,
                      l10n.libraryTabCollection,
                      l10n.libraryTabWishlist,
                      l10n.libraryTabFavorites,
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _SearchRibbonField(
                          controller: _search,
                          hint: onAll
                              ? l10n.librarySearchCatalog
                              : l10n.librarySearchCollection,
                          onChanged: _onQueryChanged,
                          onClear: () {
                            _search.clear();
                            _onQueryChanged('');
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      _RibbonButton(
                        key: const Key('library-filters'),
                        icon: Icons.tune_rounded,
                        tooltip: l10n.libraryFiltersTitle,
                        badge: _browse.activeFilterCount,
                        onTap: _openFilters,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      _RibbonButton(
                        key: const Key('library-sort'),
                        icon: Icons.sort_rounded,
                        tooltip: l10n.librarySortLabel,
                        onTap: _openSort,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _AllGamesTab(browse: _browse.copyWith(query: _query)),
                for (final filter in const [
                  CollectionFilter.owned,
                  CollectionFilter.wishlisted,
                  CollectionFilter.favorited,
                ])
                  _CollectionTab(
                    filter: filter,
                    query: _query,
                    onBrowse: () => _tabs.animateTo(0),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Web library tab bar: bold text-sm labels, `gap-6`, the active one
/// primary with a 4px rounded-top underline.
class _UnderlineTabs extends StatelessWidget {
  const _UnderlineTabs({required this.controller, required this.labels});

  final TabController controller;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      dividerColor: AppColors.transparent,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.only(right: AppSpacing.xl),
      indicatorSize: TabBarIndicatorSize.label,
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(width: 4, color: AppColors.primary),
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.onSurfaceVariant,
      labelStyle: AppTypography.titleSmall,
      unselectedLabelStyle: AppTypography.titleSmall,
      overlayColor: const WidgetStatePropertyAll(AppColors.transparent),
      tabs: [
        for (final l in labels) Tab(height: 52, text: l),
      ],
    );
  }
}

/// `bg-surface-container-low rounded-2xl` search input of the ribbon.
class _SearchRibbonField extends StatelessWidget {
  const _SearchRibbonField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final shape = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      borderSide: BorderSide.none,
    );
    return SizedBox(
      height: 44,
      child: TextField(
        key: const Key('library-search'),
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: AppTypography.bodyMedium,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTypography.bodyMedium.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
          filled: true,
          fillColor: AppColors.surfaceContainerLow,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppColors.onSurfaceVariant,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 44),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: context.l10n.commonClose,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: onClear,
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
    );
  }
}

/// 44px `rounded-2xl bg-surface-container-high` primary icon button with
/// an optional count badge.
class _RibbonButton extends StatelessWidget {
  const _RibbonButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              onTap: onTap,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(icon, color: AppColors.primary),
              ),
            ),
          ),
          if (badge > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 2),
                ),
                child: Text(
                  '$badge',
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Grid padding: `mt-4` + page gutter, clear of the bottom nav.
const _gridPadding = EdgeInsets.fromLTRB(
  AppSpacing.lg,
  AppSpacing.lg,
  AppSpacing.lg,
  120,
);

class _AllGamesTab extends ConsumerStatefulWidget {
  const _AllGamesTab({required this.browse});

  final GameBrowseQuery browse;

  @override
  ConsumerState<_AllGamesTab> createState() => _AllGamesTabState();
}

class _AllGamesTabState extends ConsumerState<_AllGamesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis == Axis.vertical &&
        n.metrics.pixels >= n.metrics.maxScrollExtent - 400) {
      final notifier = ref.read(libraryBrowseProvider(widget.browse).notifier);
      if (!notifier.isLoadingMore) {
        notifier.loadMore().then((_) {
          if (mounted) setState(() {});
        });
        setState(() {});
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;
    final provider = libraryBrowseProvider(widget.browse);
    final results = ref.watch(provider);
    final loadingMore = ref.read(provider.notifier).isLoadingMore;
    final page = results.valueOrNull;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(provider),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (widget.browse.query.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  0,
                ),
                sliver: SliverToBoxAdapter(child: SpotlightHero()),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                widget.browse.query.isEmpty ? AppSpacing.xxl : AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.libraryFeedTitle,
                        style: AppTypography.headlineSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n
                          .libraryFeedResults('${page?.totalElements ?? 0}')
                          .toUpperCase(),
                      key: const Key('library-feed-count'),
                      style: AppTypography.eyebrow.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color:
                            AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ...results.when(
              loading: () => [_gridSkeleton(6)],
              error: (e, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorState(
                    error: e,
                    title: l10n.libraryDatabaseUnavailable,
                    onRetry: () => ref.invalidate(provider),
                  ),
                ),
              ],
              data: (page) => page.content.isEmpty
                  ? [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          120,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: _FeedEmpty(
                            recommended: widget.browse.sort == 'recommended',
                          ),
                        ),
                      ),
                    ]
                  : [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        sliver: SliverLayoutBuilder(
                          builder: (context, constraints) => SliverGrid.builder(
                            gridDelegate: libraryGridDelegate(
                              constraints.crossAxisExtent,
                            ),
                            itemCount: page.content.length,
                            itemBuilder: (_, i) {
                              final game = page.content[i];
                              return LibraryGameTile(
                                game: game,
                                onTap: () =>
                                    context.push(AppRoutes.gameDetail(game.id)),
                              );
                            },
                          ),
                        ),
                      ),
                      if (loadingMore && page.hasMore)
                        _gridSkeleton(2, top: AppSpacing.xxl + 8)
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            40,
                            AppSpacing.lg,
                            120,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: page.last
                                ? Text(
                                    l10n.libraryFeedEnd.toUpperCase(),
                                    textAlign: TextAlign.center,
                                    style: AppTypography.eyebrow.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.onSurfaceVariant
                                          .withValues(alpha: 0.4),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                    ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _gridSkeleton(int count, {double top = 0}) => SliverPadding(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, top, AppSpacing.lg, 120),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) => SliverGrid.builder(
            gridDelegate: libraryGridDelegate(constraints.crossAxisExtent),
            itemCount: count,
            itemBuilder: (_, __) =>
                const SkeletonShimmer(child: LibraryTileSkeleton()),
          ),
        ),
      );
}

/// Web `text-center py-20 bg-surface-container-lowest rounded-[2rem]` panel.
class _FeedEmpty extends StatelessWidget {
  const _FeedEmpty({required this.recommended});

  final bool recommended;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _EmptyPanel(
      radius: 32,
      icon: Icons.explore_off_outlined,
      iconSize: 60,
      iconAlpha: 0.2,
      title: recommended
          ? l10n.libraryFeedNoRecommendations
          : l10n.libraryFeedEmpty,
      body: recommended
          ? l10n.libraryFeedNoRecommendationsBody
          : l10n.libraryFeedEmptyBody,
      titleStyle: AppTypography.titleLarge,
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.radius,
    required this.titleStyle,
    this.body,
    this.iconSize = 72,
    this.iconAlpha = 0.1,
    this.action,
    this.vertical = 80,
  });

  final IconData icon;
  final String title;
  final String? body;
  final double radius;
  final double iconSize;
  final double iconAlpha;
  final TextStyle titleStyle;
  final Widget? action;
  final double vertical;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: vertical,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: iconSize,
            color: AppColors.primary.withValues(alpha: iconAlpha),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: titleStyle, textAlign: TextAlign.center),
          if (body != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                body!,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: AppSpacing.xl),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Game of the Week hero (web spotlight; the game is a fixed pick).
class SpotlightHero extends ConsumerStatefulWidget {
  const SpotlightHero({super.key});

  static const title = 'Gloomhaven';
  static const imageUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuD9OrJ1s0wkQqNwd_2YHUbBl6iHCyN8nOBpB4M5CCRPcCrAdiFtFi6vdGS7g51uWG11sEi2A5xZ224aDw5sUYAf5hAOBolULCapAp1U2NWzEUAn_m7t1eK_1q4g-mM8sv8KTArVqCvmLHfz1szDbFToCottMw8Y9l99X7PAbtnF4V5WjZEeNd784ek1C-GJ2U_pw2-CzblT4s91OMRI2OG9cn0CVbWT5_Dsc7UUa3uasDGIn6zx5pkZN2v-oEsMxd98qQvrdP7Nqw0';

  @override
  ConsumerState<SpotlightHero> createState() => _SpotlightHeroState();
}

class _SpotlightHeroState extends ConsumerState<SpotlightHero> {
  bool _saving = false;

  Future<Game?> _find() async {
    final page = await ref
        .read(gameRepositoryProvider)
        .searchGames(query: SpotlightHero.title);
    return page.content.isEmpty ? null : page.content.first;
  }

  Future<void> _explore() async {
    try {
      final game = await _find();
      if (game != null && mounted) {
        await context.push(AppRoutes.gameDetail(game.id));
      }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    setState(() => _saving = true);
    try {
      final game = await _find();
      if (game == null) return;
      await ref
          .read(collectionNotifierProvider.notifier)
          .setFlags(game, isFavorited: true);
      if (mounted) {
        showToast(
          context,
          l10n.librarySpotlightSaved(SpotlightHero.title),
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      key: const Key('library-spotlight'),
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 25,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const SafeNetworkImage(
              url: SpotlightHero.imageUrl,
              fallback: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF3B2A1A), Color(0xFF1B1410)],
                  ),
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color(0xE6000000),
                    Color(0x4D000000),
                    Color(0x00000000),
                  ],
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.xl,
              right: AppSpacing.xl,
              bottom: AppSpacing.xl,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: AppSpacing.borderRadiusFull,
                          ),
                          child: Text(
                            l10n.librarySpotlightCategory.toUpperCase(),
                            style: AppTypography.labelSmall.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: AppColors.onPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          SpotlightHero.title,
                          style: AppTypography.headlineMedium.copyWith(
                            color: AppColors.onPrimary,
                            letterSpacing: 0,
                          ),
                        ),
                        Text(
                          l10n.librarySpotlightDescription,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.onPrimary.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Material(
                    color: AppColors.surfaceContainerLowest,
                    shape: const StadiumBorder(),
                    elevation: 4,
                    shadowColor: AppColors.shadow.withValues(alpha: 0.3),
                    child: InkWell(
                      key: const Key('spotlight-explore'),
                      customBorder: const StadiumBorder(),
                      onTap: _explore,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: AppSpacing.sm,
                        ),
                        child: Text(
                          l10n.librarySpotlightExplore,
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.onBackground,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  CircleIconButton(
                    key: const Key('spotlight-save'),
                    icon: Icons.bookmark_border_rounded,
                    iconSize: 20,
                    size: 36,
                    tooltip: l10n.librarySpotlightSave,
                    color: AppColors.onPrimary.withValues(alpha: 0.1),
                    iconColor: AppColors.onPrimary,
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionTab extends ConsumerStatefulWidget {
  const _CollectionTab({
    required this.filter,
    required this.query,
    required this.onBrowse,
  });

  final CollectionFilter filter;
  final String query;
  final VoidCallback onBrowse;

  @override
  ConsumerState<_CollectionTab> createState() => _CollectionTabState();
}

class _CollectionTabState extends ConsumerState<_CollectionTab> {
  String? _rating;

  Future<void> _rate(UserGame entry, double rating) async {
    final l10n = context.l10n;
    setState(() => _rating = entry.gameId);
    try {
      await ref
          .read(collectionNotifierProvider.notifier)
          .rate(entry.game, rating: rating);
    } catch (_) {
      if (mounted) {
        showToast(context, l10n.libraryRatingSaveFailed, type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _rating = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final collection = ref.watch(collectionNotifierProvider);
    return collection.when(
      loading: () => CustomScrollView(
        slivers: [
          SliverPadding(
            padding: _gridPadding,
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) => SliverGrid.builder(
                gridDelegate: libraryGridDelegate(constraints.crossAxisExtent),
                itemCount: 6,
                itemBuilder: (_, __) =>
                    const SkeletonShimmer(child: LibraryTileSkeleton()),
              ),
            ),
          ),
        ],
      ),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () => ref.invalidate(collectionNotifierProvider),
      ),
      data: (state) {
        final q = widget.query.toLowerCase();
        final all = state.filtered(widget.filter);
        final entries = q.isEmpty
            ? all
            : all.where((g) => g.game.name.toLowerCase().contains(q)).toList();
        return RefreshIndicator(
          onRefresh: () =>
              ref.read(collectionNotifierProvider.notifier).refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (state.cachedAt != null)
                SliverToBoxAdapter(
                  child: StaleDataBanner(cachedAt: state.cachedAt!),
                ),
              if (entries.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.lg,
                    120,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: q.length >= 2 && state.items.isNotEmpty
                        ? _EmptyPanel(
                            radius: 48,
                            vertical: 96,
                            icon: Icons.search_off_rounded,
                            title: l10n.libraryNoMatch(widget.query),
                            titleStyle: AppTypography.bodyMedium.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          )
                        : _shelfEmpty(l10n),
                  ),
                )
              else
                SliverPadding(
                  padding: _gridPadding,
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) => SliverGrid.builder(
                      gridDelegate: libraryGridDelegate(
                        constraints.crossAxisExtent,
                        textExtent: collectionTileTextExtent,
                        spacing: AppSpacing.xl,
                      ),
                      itemCount: entries.length,
                      itemBuilder: (_, i) {
                        final entry = entries[i];
                        return CollectionGameTile(
                          entry: entry,
                          ratingBusy: _rating == entry.gameId,
                          onRate: (r) => _rate(entry, r),
                          onTap: () =>
                              context.push(AppRoutes.gameDetail(entry.gameId)),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _shelfEmpty(AppLocalizations l10n) {
    final (icon, title, body, browse) = switch (widget.filter) {
      CollectionFilter.wishlisted => (
          Icons.bookmark_rounded,
          l10n.libraryEmptyWishlistTitle,
          l10n.libraryEmptyWishlistBody,
          true,
        ),
      CollectionFilter.favorited => (
          Icons.favorite_rounded,
          l10n.libraryEmptyFavoritesTitle,
          l10n.libraryEmptyFavoritesBody,
          false,
        ),
      _ => (
          Icons.shelves,
          l10n.libraryEmptyCollectionTitle,
          l10n.libraryEmptyCollectionBody,
          true,
        ),
    };
    return _EmptyPanel(
      radius: 48,
      vertical: 96,
      icon: icon,
      title: title,
      body: body,
      titleStyle: AppTypography.headlineSmall.copyWith(
        fontWeight: FontWeight.w700,
      ),
      action: browse
          ? _GradientPill(
              key: const Key('library-browse'),
              label: l10n.libraryBrowseGames,
              onTap: widget.onBrowse,
            )
          : null,
    );
  }
}

/// `px-6 py-3 rounded-full bg-gradient-to-r from-primary to-primary-container`.
class _GradientPill extends StatelessWidget {
  const _GradientPill({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: AppSpacing.borderRadiusFull,
        ),
        child: Material(
          color: AppColors.transparent,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.md,
              ),
              child: Text(
                label,
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.onPrimary,
                ),
              ),
            ),
          ),
        ),
      );
}

/// Owned / wishlist / favourite icons shown on a card corner (onboarding
/// add-game grid).
class CollectionBadges extends StatelessWidget {
  const CollectionBadges({super.key, required this.entry});

  final UserGame entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final icons = [
      if (entry.isOwned) (Icons.shelves, l10n.badgeOwned),
      if (entry.isWishlisted) (Icons.bookmark_rounded, l10n.badgeWishlisted),
      if (entry.isFavorited) (Icons.star_rounded, l10n.badgeFavorited),
    ];
    if (icons.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.inverseSurface.withValues(alpha: 0.8),
        borderRadius: AppSpacing.borderRadiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (icon, label) in icons)
            Tooltip(
              message: label,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Icon(icon, size: 14, color: AppColors.primaryContainer),
              ),
            ),
        ],
      ),
    );
  }
}
