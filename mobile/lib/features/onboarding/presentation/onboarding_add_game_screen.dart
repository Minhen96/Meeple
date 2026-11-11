import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/constants/text_style_weight.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/features/library/providers/library_provider.dart';
import 'package:meeple_hearth/features/onboarding/presentation/onboarding_scaffold.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
import 'package:meeple_hearth/shared/widgets/app_card.dart';
import 'package:meeple_hearth/shared/widgets/app_text_field.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';
import 'package:meeple_hearth/shared/widgets/skeleton_widget.dart';

/// Onboarding step 5 (SCREENS §3.6): search (popular games when empty) and
/// quick-add to the collection, then finish.
class OnboardingAddGameScreen extends ConsumerStatefulWidget {
  const OnboardingAddGameScreen({super.key});

  @override
  ConsumerState<OnboardingAddGameScreen> createState() =>
      _OnboardingAddGameScreenState();
}

class _OnboardingAddGameScreenState
    extends ConsumerState<OnboardingAddGameScreen> {
  Timer? _debounce;
  String _query = '';
  bool _finishing = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _quickAdd(Game game) async {
    final l10n = context.l10n;
    final add = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXxl),
        ),
      ),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (game.coverUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      child: CachedNetworkImage(
                        imageUrl: game.coverUrl!,
                        width: 64,
                        height: 80,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const SizedBox(
                          width: 64,
                          height: 80,
                          child: ColoredBox(
                            color: AppColors.surfaceContainerHigh,
                          ),
                        ),
                      ),
                    ),
                    AppSpacing.hGapLg,
                  ],
                  Expanded(
                    child: Text(
                      l10n.onboardingAddGameConfirm(game.name),
                      style: AppTypography.titleLarge.weight(FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AppButton(
                key: const Key('quick-add-confirm'),
                label: l10n.gameAddToCollection,
                onPressed: () => Navigator.of(sheet).pop(true),
              ),
              AppSpacing.vGapMd,
              AppButton(
                label: l10n.commonCancel,
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.of(sheet).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
    if (add != true || !mounted) return;
    try {
      await ref
          .read(collectionNotifierProvider.notifier)
          .setFlags(game, isOwned: true);
      if (mounted) {
        showToast(context, l10n.gameAddedToCollection, type: ToastType.success);
      }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final results = ref.watch(gameSearchNotifierProvider(_query));
    final owned = ref.watch(collectionNotifierProvider).valueOrNull;
    const grid = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      childAspectRatio: 0.58,
    );
    return OnboardingScaffold(
      route: AppRoutes.onboardingAddGame,
      title: l10n.onboardingAddGameTitle,
      subtitle: l10n.onboardingAddGameBody,
      bottom: AppButton(
        key: const Key('onboarding-finish'),
        label: l10n.onboardingFinish,
        isLoading: _finishing,
        onPressed: () async {
          setState(() => _finishing = true);
          await goToNextOnboardingStep(
              context, ref, AppRoutes.onboardingAddGame);
          if (mounted) setState(() => _finishing = false);
        },
      ),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: onboardingGutter),
            sliver: SliverList.list(
              children: [
                TextField(
                  key: const Key('onboarding-game-search'),
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 400), () {
                      if (mounted) setState(() => _query = v.trim());
                    });
                  },
                  style: AppTypography.bodyMedium,
                  decoration: appFieldDecoration(
                    hint: l10n.onboardingGameSearchHint,
                    fill: AppColors.surfaceContainerHighest,
                    radius: AppRadius.tile,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                  ).copyWith(
                    hintStyle: AppTypography.bodyMedium
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ),
                AppSpacing.vGapLg,
                if (_query.isEmpty)
                  SectionLabel(
                    l10n.onboardingPopular,
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              onboardingGutter,
              0,
              onboardingGutter,
              AppSpacing.lg,
            ),
            sliver: results.when(
              loading: () => SliverGrid.builder(
                gridDelegate: grid,
                itemCount: 9,
                itemBuilder: (_, __) => const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SkeletonBox(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                        height: double.infinity,
                      ),
                    ),
                    AppSpacing.vGapSm,
                    SkeletonBox(width: 60, height: 10),
                  ],
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: ErrorState(
                  error: e,
                  onRetry: () =>
                      ref.invalidate(gameSearchNotifierProvider(_query)),
                ),
              ),
              data: (page) => page.content.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xxl,
                        ),
                        child: Text(
                          l10n.libraryNoResults(_query),
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium
                              .copyWith(color: AppColors.onSurfaceVariant),
                        ),
                      ),
                    )
                  : SliverGrid.builder(
                      gridDelegate: grid,
                      itemCount: page.content.length,
                      itemBuilder: (_, i) {
                        final g = page.content[i];
                        return _AddGameTile(
                          game: g,
                          inCollection: owned?.entryFor(g.id)?.isOwned ?? false,
                          onTap: () => _quickAdd(g),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Web onboarding game tile: 3:4 cover (rounded, surface-container-high),
/// a teal check when it is in the collection, and a 2-line bold title.
class _AddGameTile extends StatelessWidget {
  const _AddGameTile({
    required this.game,
    required this.inCollection,
    required this.onTap,
  });

  final Game game;
  final bool inCollection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const placeholder = Center(
      child: Icon(Icons.casino_outlined, color: AppColors.onSurfaceVariant),
    );
    return GestureDetector(
      key: ValueKey('add-game-${game.id}'),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.tile),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (game.coverUrl == null)
                    placeholder
                  else
                    CachedNetworkImage(
                      imageUrl: game.coverUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => placeholder,
                    ),
                  if (inCollection)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Tooltip(
                        message: context.l10n.onboardingInCollection,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: AppColors.tertiaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: AppColors.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          AppSpacing.vGapXs,
          Text(
            game.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall
                .weight(FontWeight.w700)
                .copyWith(color: AppColors.onSurface, height: 1.25),
          ),
        ],
      ),
    );
  }
}
