import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/features/library/presentation/library_screen.dart';
import 'package:meeple_hearth/features/library/presentation/widgets/game_card.dart';
import 'package:meeple_hearth/features/library/providers/library_provider.dart';
import 'package:meeple_hearth/features/onboarding/presentation/onboarding_scaffold.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
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
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.onboardingAddGameConfirm(game.name),
                style: AppTypography.titleLarge,
                textAlign: TextAlign.center,
              ),
              AppSpacing.vGapLg,
              AppButton(
                key: const Key('quick-add-confirm'),
                label: l10n.gameAddToCollection,
                onPressed: () => Navigator.of(sheet).pop(true),
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
          await goToNextOnboardingStep(context, ref, AppRoutes.onboardingAddGame);
          if (mounted) setState(() => _finishing = false);
        },
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: TextField(
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), () {
                  if (mounted) setState(() => _query = v.trim());
                });
              },
              decoration: InputDecoration(
                hintText: l10n.librarySearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          if (_query.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(l10n.onboardingPopular, style: AppTypography.titleMedium),
              ),
            ),
          Expanded(
            child: results.when(
              loading: () => GridView.count(
                crossAxisCount: 3,
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: List.filled(6, const GameCardSkeleton()),
              ),
              error: (e, _) => ErrorState(
                error: e,
                onRetry: () => ref.invalidate(gameSearchNotifierProvider(_query)),
              ),
              data: (page) => page.content.isEmpty
                  ? Center(child: Text(l10n.libraryNoResults(_query)))
                  : GridView.builder(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: AppSpacing.md,
                        mainAxisSpacing: AppSpacing.lg,
                        childAspectRatio: 0.62,
                      ),
                      itemCount: page.content.length,
                      itemBuilder: (_, i) {
                        final g = page.content[i];
                        final entry = owned?.entryFor(g.id);
                        return GameCard(
                          game: g,
                          trailing:
                              entry == null ? null : CollectionBadges(entry: entry),
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
