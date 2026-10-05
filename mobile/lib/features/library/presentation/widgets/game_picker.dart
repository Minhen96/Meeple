import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/features/library/presentation/widgets/game_card.dart';
import 'package:meeple_hearth/features/library/providers/library_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';

/// Searches the catalogue and resolves to the chosen game (null when
/// dismissed). The viewer's collection is offered first while the query is
/// empty.
Future<Game?> showGamePicker(BuildContext context) =>
    showModalBottomSheet<Game>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.85,
        child: GamePicker(),
      ),
    );

class GamePicker extends ConsumerStatefulWidget {
  const GamePicker({super.key});

  @override
  ConsumerState<GamePicker> createState() => _GamePickerState();
}

class _GamePickerState extends ConsumerState<GamePicker> {
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final collection = ref.watch(collectionNotifierProvider).valueOrNull;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: TextField(
            key: const Key('game-picker-search'),
            autofocus: true,
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
        AppSpacing.vGapSm,
        Expanded(
          child: _query.isEmpty && (collection?.items.isNotEmpty ?? false)
              ? ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      child: Text(
                        l10n.libraryTabCollection,
                        style: AppTypography.titleSmall,
                      ),
                    ),
                    for (final entry in collection!.items)
                      GameListTile(
                        key: ValueKey('pick-${entry.gameId}'),
                        game: entry.game,
                        onTap: () => Navigator.of(context).pop(entry.game),
                      ),
                  ],
                )
              : ref.watch(gameSearchNotifierProvider(_query)).when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => ErrorState(
                      error: e,
                      onRetry: () =>
                          ref.invalidate(gameSearchNotifierProvider(_query)),
                    ),
                    data: (page) => page.content.isEmpty
                        ? Center(
                            child: Text(
                              l10n.libraryNoResults(_query),
                              style: AppTypography.bodyMedium,
                            ),
                          )
                        : ListView.builder(
                            itemCount: page.content.length,
                            itemBuilder: (_, i) => GameListTile(
                              key: ValueKey('pick-${page.content[i].id}'),
                              game: page.content[i],
                              subtitle: page.content[i].yearPublished?.toString(),
                              onTap: () =>
                                  Navigator.of(context).pop(page.content[i]),
                            ),
                          ),
                  ),
        ),
      ],
    );
  }
}
